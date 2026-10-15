#import <Foundation/Foundation.h>
#import <dlfcn.h>
#import <objc/message.h>
typedef Boolean (*Control)(CFStringRef, void *, CFErrorRef *);
void describe(id object, NSString *prefix) {
    if ([object isKindOfClass:NSDictionary.class]) {
        for (id key in object) { printf("%s%s: %s\n", prefix.UTF8String, [[key description] UTF8String], [NSStringFromClass([object[key] class]) UTF8String]); describe(object[key], [prefix stringByAppendingString:@"  "]); }
    } else if ([object isKindOfClass:NSArray.class]) { for(id child in object) describe(child, [prefix stringByAppendingString:@"  "]); }
}
int main(int argc, char **argv) { @autoreleasepool {
    dlopen("/System/Library/Frameworks/Security.framework/Security", RTLD_NOW);
    Control control = (Control)dlsym(RTLD_DEFAULT, "SecAssessmentControl");
    CFDictionaryRef rejection=NULL; CFErrorRef error=NULL;
    Boolean ok=control(CFSTR("ui-recall-reject"), &rejection, &error);
    printf("Read last rejection: %d\n", ok); if(error)CFShow(error);
    if (!rejection || argc != 2) return 2;
    NSDictionary *record = (__bridge id)rejection;
    NSError *resolveError=nil;
    NSURL *url = [NSURL URLByResolvingBookmarkData:record[@"BookmarkData"] options:NSURLBookmarkResolutionWithoutUI | NSURLBookmarkResolutionWithoutMounting relativeToURL:nil bookmarkDataIsStale:nil error:&resolveError];
    NSString *expected = [NSString stringWithUTF8String:argv[1]];
    if (![url.path.stringByResolvingSymlinksInPath isEqualToString:expected.stringByResolvingSymlinksInPath]) { puts("Refused: last rejection does not match our disposable app exactly."); return 2; }
    puts("Last rejection matches our disposable app exactly.");
    dlopen("/System/Library/PrivateFrameworks/SystemPolicy.framework/SystemPolicy", RTLD_NOW);
    id policy = [NSClassFromString(@"SPExecutionPolicy") new];
    SEL selector = NSSelectorFromString(@"addGatekeeperUserIntent:error:");
    if (![policy respondsToSelector:selector]) { puts("Native override selector unavailable"); return 2; }
    NSError *overrideError=nil;
    BOOL result = ((BOOL(*)(id,SEL,id,NSError **))objc_msgSend)(policy, selector, url, &overrideError);
    printf("Native user-intent result: %d\n", result);
    if(overrideError)NSLog(@"%@",overrideError);
} }
