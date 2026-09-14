#import <UIKit/UIKit.h>
#import "Core/SGCore.h"
#import "ControlPanel.h"

API_AVAILABLE(ios(17.0))
@interface SGPanelActivity : NSObject
+ (void)listen;
+ (void)start;
+ (void)end;
@end

%ctor {
    if (@available(iOS 17.0, *)) {
        if (!SGFlag(SGKeyControlPanel, NO)) {
            dispatch_async(dispatch_get_main_queue(), ^{ [SGPanelActivity end]; });
            return;
        }
        [SGPanelActivity listen];
        [NSNotificationCenter.defaultCenter addObserverForName:UIApplicationDidBecomeActiveNotification object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *note) {
            [SGPanelActivity start];
        }];
        SGLog(@"control panel: on");
    }
}
