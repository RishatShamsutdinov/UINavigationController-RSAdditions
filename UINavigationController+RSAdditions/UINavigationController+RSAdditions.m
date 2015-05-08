/**
 *
 * Copyright 2015 Rishat Shamsutdinov
 * 
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 * 
 *     http://www.apache.org/licenses/LICENSE-2.0
 * 
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 *
 */

#import "UINavigationController+RSAdditions.h"

#import <RSSwizzlingMacros.h>
#import <RSWeakObjectContainer.h>

NSString * const RS_UINavigationControllerWillShowViewControllerNotification = @"RS_UINavigationControllerWillShowViewControllerNotification";
NSString * const RS_UINavigationControllerDidShowViewControllerNotification = @"RS_UINavigationControllerDidShowViewControllerNotification";

NSString * const RS_UINavigationControllerViewControllerKey = @"RS_UINavigationControllerViewControllerKey";
NSString * const RS_UINavigationControllerAnimatedKey = @"RS_UINavigationControllerAnimatedKey";

NSString * const RS_UINavigationControllerWillChangeNavigationBarVisibility = @"RS_UINavigationControllerWillChangeNavigationBarVisibility";
NSString * const RS_UINavigationControllerDidChangeNavigationBarVisibility = @"RS_UINavigationControllerDidChangeNavigationBarVisibility";

#pragma mark - _RS_UINavigationControllerDelegateProxy

@interface _RS_UINavigationControllerDelegateProxy : NSProxy <UINavigationControllerDelegate> {
    id __weak _target;
}

- (instancetype)initWithTarget:(id)target;

@end

@implementation _RS_UINavigationControllerDelegateProxy

static const void * kLockKey = &kLockKey;

- (instancetype)initWithTarget:(id)target {
    _target = target;

    return self;
}

- (NSMethodSignature *)methodSignatureForSelector:(SEL)sel {
    return [_target methodSignatureForSelector:sel];
}

- (void)forwardInvocation:(NSInvocation *)invocation {
    [invocation invokeWithTarget:_target];
}

- (BOOL)respondsToSelector:(SEL)aSelector {
    return (aSelector == @selector(navigationController:willShowViewController:animated:) ||
            aSelector == @selector(navigationController:didShowViewController:animated:) ||
            [_target respondsToSelector:aSelector]);
}

- (void)navigationController:(UINavigationController *)navigationController
      willShowViewController:(UIViewController *)viewController animated:(BOOL)animated {

    [[NSNotificationCenter defaultCenter]
     postNotificationName:RS_UINavigationControllerWillShowViewControllerNotification
     object:navigationController
     userInfo:@{RS_UINavigationControllerViewControllerKey: viewController,
                RS_UINavigationControllerAnimatedKey: @(animated)}];

    if ([_target respondsToSelector:_cmd]) {
        [_target navigationController:navigationController willShowViewController:viewController animated:animated];
    }
}

- (void)navigationController:(UINavigationController *)navigationController
       didShowViewController:(UIViewController *)viewController animated:(BOOL)animated {

    objc_setAssociatedObject(navigationController, kLockKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    [[NSNotificationCenter defaultCenter]
     postNotificationName:RS_UINavigationControllerDidShowViewControllerNotification
     object:navigationController
     userInfo:@{RS_UINavigationControllerViewControllerKey: viewController,
                RS_UINavigationControllerAnimatedKey: @(animated)}];

    if ([_target respondsToSelector:_cmd]) {
        [_target navigationController:navigationController didShowViewController:viewController animated:animated];
    }
}

@end

#pragma mark - UINavigationController (RSAdditions)

@implementation UINavigationController (RSAdditions)

static IMP RS_ORIGINAL_IMP(setDelegate);
static IMP RS_ORIGINAL_IMP(viewDidLoad);
static IMP RS_ORIGINAL_IMP(setNavigationBarHiddenAnimated);
static IMP RS_ORIGINAL_IMP(pushViewControllerAnimated);

static const void * kProxyKey = &kProxyKey;

static void RS_SWIZZLED_METHOD(setDelegate, id<UINavigationControllerDelegate> delegate) {
    _RS_UINavigationControllerDelegateProxy *proxy;

    if ([delegate isMemberOfClass:[_RS_UINavigationControllerDelegateProxy class]]) {
        proxy = delegate;
    } else {
        proxy = [[_RS_UINavigationControllerDelegateProxy alloc] initWithTarget:delegate];

        objc_setAssociatedObject(self, kProxyKey, proxy, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }

    RS_INVOKE_ORIGINAL_IMP1(void, setDelegate, proxy);
}

static void RS_SWIZZLED_METHOD_WO_ARGS(viewDidLoad) {
    RS_INVOKE_ORIGINAL_IMP0(void, viewDidLoad);

    if ([self isKindOfClass:[UINavigationController class]]) {
        UINavigationController *navigationController = self;

        if (!navigationController.delegate) {
            [navigationController setDelegate:nil];
        }
    }
}

static void RS_SWIZZLED_METHOD(setNavigationBarHiddenAnimated, BOOL hidden, BOOL animated) {
    NSNotificationCenter *notifCenter = [NSNotificationCenter defaultCenter];

    [notifCenter postNotificationName:RS_UINavigationControllerWillChangeNavigationBarVisibility object:self];

    RS_INVOKE_ORIGINAL_IMP2(void, setNavigationBarHiddenAnimated, hidden, animated);

    [notifCenter postNotificationName:RS_UINavigationControllerDidChangeNavigationBarVisibility object:self];
}

static void RS_SWIZZLED_METHOD(pushViewControllerAnimated, UIViewController *viewController, BOOL animated) {
    RSWeakObjectContainer *lock = objc_getAssociatedObject(self, kLockKey);

    if (lock.object) {
        return; // weird workaround to avoid double push
    }

    objc_setAssociatedObject(self, kLockKey, [RSWeakObjectContainer containerWithObject:viewController],
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    RS_INVOKE_ORIGINAL_IMP2(void, pushViewControllerAnimated, viewController, animated);
}

+ (void)load {
    Class clazz = [self class];

    RS_SWIZZLE(clazz, setDelegate:, setDelegate);
    RS_SWIZZLE(clazz, viewDidLoad, viewDidLoad);
    RS_SWIZZLE(clazz, setNavigationBarHidden:animated:, setNavigationBarHiddenAnimated);
    RS_SWIZZLE(clazz, pushViewController:animated:, pushViewControllerAnimated);
}

@end
