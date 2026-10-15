#include <CoreFoundation/CoreFoundation.h>
#include <Security/Security.h>
#include <dlfcn.h>
#include <stdio.h>
#include <string.h>
typedef Boolean (*Update)(CFTypeRef, uint64_t, CFDictionaryRef, CFErrorRef *);
int main(int argc, char **argv) {
    if (argc != 2 || strlen(argv[1]) != 40 || strspn(argv[1], "0123456789abcdef") != 40) return 2;
    Update update = (Update)dlsym(RTLD_DEFAULT, "SecAssessmentUpdate");
    if (!update) { puts("SecAssessmentUpdate unavailable"); return 1; }
    CFStringRef requirementText = CFStringCreateWithFormat(NULL, NULL, CFSTR("cdhash H\"%s\""), argv[1]);
    SecRequirementRef requirement = NULL;
    OSStatus status = SecRequirementCreateWithString(requirementText, 0, &requirement);
    if (status) { printf("Requirement error: %d\n", status); return 1; }
    const void *keys[] = {CFSTR("update"), CFSTR("operation"), CFSTR("update:label")};
    const void *values[] = {CFSTR("update:add"), CFSTR("operation:execute"), CFSTR("TrustMeDisposableProbe")};
    CFDictionaryRef context = CFDictionaryCreate(NULL, keys, values, 3, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
    CFErrorRef error = NULL;
    Boolean result = update(requirement, 0, context, &error);
    printf("Exact-disposable-code-hash add result: %d\n", result);
    if (error) CFShow(error);
    if (result) {
        const void *removeValues[] = {CFSTR("update:remove"), CFSTR("operation:execute"), CFSTR("TrustMeDisposableProbe")};
        CFDictionaryRef removeContext = CFDictionaryCreate(NULL, keys, removeValues, 3, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
        printf("Probe cleanup result: %d\n", update(requirement, 0, removeContext, NULL));
    }
    return 0;
}
