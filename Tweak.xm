#import <SpringBoard/SpringBoard.h>
#import "header.h"
#import <CommonCrypto/CommonDigest.h>
#include <spawn.h>

#define SETTINGS_PLIST_PATH @"/var/mobile/Library/Preferences/com.xcxiao.bottomcontrolxpreferences.plist"
#define PreferencesName     CFSTR("com.xcxiao.bottomcontrolxpreferences")

#define Home                1
#define CCC                 2
#define Lock                3
#define CS                  9
#define ScreenShot          5
#define NoAction            10

#define kiOSVersion         [[UIDevice currentDevice].systemVersion doubleValue]
#define kScreenWidth        [UIScreen mainScreen].bounds.size.width
#define kScreenHeight       [UIScreen mainScreen].bounds.size.height
#define dic                 [[NSDictionary alloc] initWithContentsOfFile:SETTINGS_PLIST_PATH]

#define readThePreferencesFile(key, valueType, defaultValue) ((id)CFPreferencesCopyAppValue((CFStringRef)key, PreferencesName) ? [(id)CFPreferencesCopyAppValue((CFStringRef)key, PreferencesName) valueType] : defaultValue)

static int      SBBottomLeftGesture          = 1;
static int      SBBottomCenterGesture        = 1;
static int      SBBottomRightGesture         = 1;

static int      LBottomLeftGesture           = 1;
static int      LBottomCenterGesture         = 1;
static int      LBottomRightGesture          = 1;

static int      AppBottomLeftGesture         = 1;
static int      AppBottomCenterGesture       = 1;
static int      AppBottomRightGesture        = 1;

static CGFloat  leftValue                    = 0;
static CGFloat  rightValue                   = 0;
static float    velocityValue                = 350;
static BOOL     lowerSensibility             = NO;
static BOOL     enabled                      = NO;

// static BOOL     bringControlCenterUp         = NO;
// static int      location                     = 1;


static UIViewController* topMostController() {
    UIViewController *topController = [UIApplication sharedApplication].keyWindow.rootViewController;
    while (topController.presentedViewController) {
        topController = topController.presentedViewController;
    }
    
    return topController;
}

static void showAlert(NSString *myMessage) {
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"Alert" message:myMessage preferredStyle:UIAlertControllerStyleAlert];
    [alertController addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
    [topMostController() presentViewController:alertController animated:YES completion:nil];
}


inline int handleSwipeUpGesture(CGFloat startPoint, int left, int center, int right) {

    int gesture = 0;
    int ori = [((SpringBoard *)[UIApplication sharedApplication]) _frontMostAppOrientation];
    if(ori == 1) {
        gesture = (startPoint <= leftValue) ? left
                                            : (startPoint <= rightValue ? center
                                                                        : right);
    }else if(ori == 3 || ori == 4) {
        gesture = (startPoint <= kScreenWidth/3) ? left
                                                 : (startPoint <= kScreenWidth*2/3 ? center
                                                                                   : right);
    }

    switch(gesture) {
        case Home :
            return 0;
        case CCC :
            [[%c(SBControlCenterController) sharedInstance] presentAnimated:YES];
            return 1;
        case Lock :
            [(SpringBoard *)[UIApplication sharedApplication] _simulateLockButtonPress];
            return 1;
        case CS :
            [[%c(SBCoverSheetPresentationManager) sharedInstance] setCoverSheetPresented:YES animated:YES withCompletion:nil];
            return 1;
        case ScreenShot :
            [(SpringBoard *)[UIApplication sharedApplication] takeScreenshot];
            return 1;
        case NoAction :
            return -1;
        default :
            return 0;
    }
}

static void reloadSettings(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {

    enabled                   = readThePreferencesFile(@"EnabledBCCX", boolValue, YES);
    lowerSensibility          = readThePreferencesFile(@"lowerSensibility", boolValue, NO);
    SBBottomLeftGesture       = readThePreferencesFile(@"bottomLeftGesture", intValue, 1);
    SBBottomCenterGesture     = readThePreferencesFile(@"bottomCenterGesture", intValue, 1);
    SBBottomRightGesture      = readThePreferencesFile(@"bottomRightGesture", intValue, 1);

    LBottomLeftGesture        = readThePreferencesFile(@"LBottomLeftGesture", intValue, 1);
    LBottomCenterGesture      = readThePreferencesFile(@"LBottomCenterGesture", intValue, 1);
    LBottomRightGesture       = readThePreferencesFile(@"LBottomRightGesture", intValue, 1);

    AppBottomLeftGesture      = readThePreferencesFile(@"AppBottomLeftGesture", intValue, 1);
    AppBottomCenterGesture    = readThePreferencesFile(@"AppBottomCenterGesture", intValue, 1);
    AppBottomRightGesture     = readThePreferencesFile(@"AppBottomRightGesture", intValue, 1);

    velocityValue             = readThePreferencesFile(@"velocityValue", floatValue, 650);

}

%group Gesture

// handle coversheet gesture
%hook SBCoverSheetPrimarySlidingViewController

-(void)_handleDismissGesture:(id)arg1 {

    CGPoint point = [self _locationForGesture:[self dismissGestureRecognizer]];
	//showAlert([NSString stringWithFormat:@"参数arg3 %f，%f", point.x, point.y]);

    BOOL hasBeenAuthenticated = NO;
    if(kiOSVersion >= 13.0) hasBeenAuthenticated = [[[%c(SBLockScreenManager) sharedInstance] coverSheetViewController] isAuthenticated];
    else hasBeenAuthenticated = [[[%c(SBLockScreenManager) sharedInstance] lockScreenViewController] isAuthenticated];
    if(hasBeenAuthenticated || handleSwipeUpGesture(point.x, LBottomLeftGesture, LBottomCenterGesture, LBottomRightGesture) == 0) {
        %orig;
        return;
    }
}

%end

// expand the gesture area when using landscape mode
%hook SBFluidSwitcherGestureExclusionTrapezoid

-(BOOL)shouldBeginGestureAtStartingPoint:(CGPoint)arg1 velocity:(CGPoint)arg2 bounds:(CGRect)arg3 {
    return YES;
}

-(BOOL)allowHorizontalSwipesOutsideTrapezoid {
    return YES;
}

%end

// handle fluid gesture
%hook SBFluidSwitcherGestureManager

//你好 在SBFluidSwitcherGestureManager中，有一个名为deckGrabberTongue（SBGrabberTongue *）的变量和一个名为- (void)grabberTongueBeganPulling:(id)arg1 withDistance:(double)arg2 andVelocity:(double)arg3
//如果每次调用此功能时都要检查手势的位置，则可以决定是显示CC还是返回首页。

-(void)grabberTongueBeganPulling:(id)arg1 withDistance:(double)arg2 andVelocity:(double)arg3 {
    //DLog(@"参数：arg3 %@", arg3);
	//showAlert([NSString stringWithFormat:@"参数arg3 %@ %f，%f", arg1 , arg3, arg2]);

    int ori         = [((SpringBoard *)[UIApplication sharedApplication]) _frontMostAppOrientation];
	
	//禁用横屏手势，因为没有那个必要开启横屏手势，横屏下还容易误触
    if(ori != 1) {
        %orig;
        return;
    }
	
    //if(arg3 <= velocityValue && lowerSensibility) {
    if(arg3 <= velocityValue) {
        %orig;
        return;
    }

    CGPoint point   = [[self.deckGrabberTongue valueForKey:@"_edgePullGestureRecognizer"] locationInView:[self.deckGrabberTongue valueForKey:@"_tongueContainer"]];
	
    CGFloat pointX = (ori == 1) ? point.x
                                : (ori == 3) ? point.y
                                             : kScreenWidth - point.y;

    int result;
	
	//判断当前处于app还是桌面上，handleSwipeUpGesture是执行手势
    if(![(SpringBoard  *)[UIApplication sharedApplication] _accessibilityFrontMostApplication]) {
        result = handleSwipeUpGesture(pointX, SBBottomLeftGesture, SBBottomCenterGesture, SBBottomRightGesture);
    }else {
        result = handleSwipeUpGesture(pointX, AppBottomLeftGesture, AppBottomCenterGesture, AppBottomRightGesture);
    }

    if(result == 0)     %orig;
    if(result == -1)    return;

}

%end

// set center value when SpringBoard lanched
%hook SpringBoard

-(void)applicationDidFinishLaunching:(id)application {
    %orig;
    float center = readThePreferencesFile(@"centerValue", floatValue, kScreenWidth/3);
    leftValue    = (kScreenWidth - center)/2;
    rightValue   = (kScreenWidth - center)/2 + center;
}

%end

%end

// constructor
%ctor {
    enabled = readThePreferencesFile(@"EnabledBCCX", boolValue, YES);

    if(enabled) {
        %init(Gesture);
    }

    CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, reloadSettings, CFSTR("com.xcxiao.BCCX/reloadSettings"), NULL, CFNotificationSuspensionBehaviorCoalesce);
    reloadSettings(nil, nil, nil, nil, nil);

}
