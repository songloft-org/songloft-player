#import <objc/runtime.h>
#import <Foundation/Foundation.h>

static id _capturedJustAudioPlugin = nil;

id SongloftGetJustAudioPlugin(void) {
    return _capturedJustAudioPlugin;
}

@interface NSObject (SongloftJustAudioSwizzle)
@end

@implementation NSObject (SongloftJustAudioSwizzle)

+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Class cls = NSClassFromString(@"JustAudioPlugin");
        if (!cls) return;

        SEL originalSel = @selector(initWithRegistrar:);
        Method originalMethod = class_getInstanceMethod(cls, originalSel);
        if (!originalMethod) return;

        IMP originalImp = method_getImplementation(originalMethod);

        IMP newImp = imp_implementationWithBlock(^id(id self, id registrar) {
            id result = ((id(*)(id, SEL, id))originalImp)(self, originalSel, registrar);
            _capturedJustAudioPlugin = result;
            return result;
        });

        method_setImplementation(originalMethod, newImp);
    });
}

@end
