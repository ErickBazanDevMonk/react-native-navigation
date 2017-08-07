#import "RCCTabBarController.h"
#import "RCCViewController.h"
#import <React/RCTConvert.h>
#import "RCCManager.h"
#import "RCTHelpers.h"
#import <React/RCTUIManager.h>
#import "UIViewController+Rotation.h"
#import "RCCNavigationController.h"

@interface RCTUIManager ()

- (void)configureNextLayoutAnimation:(NSDictionary *)config
                        withCallback:(RCTResponseSenderBlock)callback
                       errorCallback:(__unused RCTResponseSenderBlock)errorCallback;

@end

@interface RCCTabBarController () <UITabBarDelegate>

@property(nonatomic, strong) UIView *holder;
@property(nonatomic, strong) UITabBar *tabBar;
@property(nullable, nonatomic,copy) NSArray<__kindof UIViewController *> *viewControllers;
@property(nullable, nonatomic, assign) __kindof UIViewController *selectedViewController; // This may return the "More" navigation controller if it exists.

@property (nonatomic, strong) NSLayoutConstraint *tabBarHeightConstraint;
@property (nonatomic, strong) NSNumber *tabBarHeight;

@end

@implementation RCCTabBarController

-(UIInterfaceOrientationMask)supportedInterfaceOrientations {
  return [self supportedControllerOrientations];
}

- (BOOL)shouldSelectViewController:(UIViewController *)viewController shouldSendJsEvent:(BOOL)shouldSendJsEvent {
  dispatch_queue_t queue = [[RCCManager sharedInstance].getBridge uiManager].methodQueue;
  dispatch_async(queue, ^{
    [[[RCCManager sharedInstance].getBridge uiManager] configureNextLayoutAnimation:nil withCallback:^(NSArray* arr){} errorCallback:^(NSArray* arr){}];
  });
  
  if (self.selectedIndex != [self.viewControllers indexOfObject:viewController] && shouldSendJsEvent) {
    NSDictionary *body = @{
                           @"selectedTabIndex": @([self.viewControllers indexOfObject:viewController]),
                           @"unselectedTabIndex": @(self.selectedIndex)
                           };
    [RCCTabBarController sendScreenTabChangedEvent:viewController body:body];
    
    [[[RCCManager sharedInstance] getBridge].eventDispatcher sendAppEventWithName:@"bottomTabSelected" body:body];
  } else {
    [RCCTabBarController sendScreenTabPressedEvent:viewController body:nil];
  }
  
  return YES;
}

- (UIImage *)image:(UIImage*)image withColor:(UIColor *)color1
{
  UIGraphicsBeginImageContextWithOptions(image.size, NO, image.scale);
  CGContextRef context = UIGraphicsGetCurrentContext();
  CGContextTranslateCTM(context, 0, image.size.height);
  CGContextScaleCTM(context, 1.0, -1.0f);
  CGContextSetBlendMode(context, kCGBlendModeNormal);
  CGRect rect = CGRectMake(0, 0, image.size.width, image.size.height);
  CGContextClipToMask(context, rect, image.CGImage);
  [color1 setFill];
  CGContextFillRect(context, rect);
  UIImage *newImage = UIGraphicsGetImageFromCurrentImageContext();
  UIGraphicsEndImageContext();
  return newImage;
}

- (instancetype)initWithProps:(NSDictionary *)props children:(NSArray *)children globalProps:(NSDictionary*)globalProps bridge:(RCTBridge *)bridge
{
  self = [super init];
  if (!self) return nil;

  UIView *holder = [[UIView alloc] init];
  self.holder = holder;
  holder.translatesAutoresizingMaskIntoConstraints = NO;
  [self.view addSubview:holder];

  UIView *tabBarHolder = [[UIView alloc] init];
  tabBarHolder.translatesAutoresizingMaskIntoConstraints = NO;
  [self.view addSubview:tabBarHolder];

  UITabBar *tabBar = [[UITabBar alloc] init];
  self.tabBar = tabBar;
  tabBar.translatesAutoresizingMaskIntoConstraints = NO;
  self.tabBar.delegate = self;
  [tabBarHolder addSubview:tabBar];

  UIView *topLine = [[UIView alloc] init];
  topLine.translatesAutoresizingMaskIntoConstraints = NO;
  topLine.backgroundColor = [UIColor colorWithRed:0.8 green:0.8 blue:0.8 alpha:1];
  [tabBarHolder addSubview:topLine];

  NSDictionary *views = @{
          @"view" : self.view,
          @"holder" : holder,
          @"topLine" : topLine,
		  @"tabBarHolder" : tabBarHolder,
          @"tabBar" : tabBar,
  };

  NSDictionary *tabsStyle = props[@"style"];
  NSNumber *tabBarHeight = tabsStyle[@"tabBarHeight"];

  NSMutableDictionary *metrics = @{}.mutableCopy;

  NSString *verticalFormat;
  if (tabBarHeight) {
	  metrics[@"tabBarHeight"] = tabBarHeight;
	  verticalFormat = @"V:|-0-[tabBar(==tabBarHeight)]";
  }
  else {
	  verticalFormat = @"V:|-0-[tabBar]-0-|";
  }

  [NSLayoutConstraint activateConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|-0-[tabBar]-0-|" options:nil metrics:metrics views:views]];
  [NSLayoutConstraint activateConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|-0-[topLine]-0-|" options:nil metrics:metrics views:views]];
  [NSLayoutConstraint activateConstraints:[NSLayoutConstraint constraintsWithVisualFormat:verticalFormat options:nil metrics:metrics views:views]];
  [NSLayoutConstraint activateConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|-0-[topLine(1)]" options:nil metrics:metrics views:views]];

  [NSLayoutConstraint activateConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|-0-[holder]-0-|" options:nil metrics:metrics views:views]];
  [NSLayoutConstraint activateConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|-0-[tabBarHolder]-0-|" options:nil metrics:metrics views:views]];
  [NSLayoutConstraint activateConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|-0-[holder]-0-[tabBarHolder]-0-|" options:nil metrics:metrics views:views]];

  self.tabBar.translucent = YES; // default
  
  UIColor *buttonColor = nil;
  UIColor *labelColor = nil;
  UIColor *selectedLabelColor = nil;

  if (tabsStyle)
  {
    NSString *tabBarButtonColor = tabsStyle[@"tabBarButtonColor"];
    if (tabBarButtonColor)
    {
      UIColor *color = tabBarButtonColor != (id)[NSNull null] ? [RCTConvert UIColor:tabBarButtonColor] : nil;
      self.tabBar.tintColor = color;
      buttonColor = color;
    }
    NSString *tabBarSelectedButtonColor = tabsStyle[@"tabBarSelectedButtonColor"];
    if (tabBarSelectedButtonColor)
    {
      UIColor *color = tabBarSelectedButtonColor != (id)[NSNull null] ? [RCTConvert UIColor:tabBarSelectedButtonColor] : nil;
      self.tabBar.tintColor = color;
    }
    NSString *tabBarLabelColor = tabsStyle[@"tabBarLabelColor"];
    if(tabBarLabelColor) {
      UIColor *color = tabBarLabelColor != (id)[NSNull null] ? [RCTConvert UIColor:tabBarLabelColor] : nil;
      labelColor = color;
    }
    NSString *tabBarSelectedLabelColor = tabsStyle[@"tabBarSelectedLabelColor"];
    if(tabBarLabelColor) {
      UIColor *color = tabBarSelectedLabelColor != (id)[NSNull null] ? [RCTConvert UIColor:
                                                                        tabBarSelectedLabelColor] : nil;
      selectedLabelColor = color;
    }
    NSString *tabBarBackgroundColor = tabsStyle[@"tabBarBackgroundColor"];
    if (tabBarBackgroundColor)
    {
      UIColor *color = tabBarBackgroundColor != (id)[NSNull null] ? [RCTConvert UIColor:tabBarBackgroundColor] : nil;
      self.tabBar.barTintColor = color;
    }

    NSString *tabBarTranslucent = tabsStyle[@"tabBarTranslucent"];
    if (tabBarTranslucent)
    {
      self.tabBar.translucent = [tabBarTranslucent boolValue];
    }

    NSString *tabBarHideShadow = tabsStyle[@"tabBarHideShadow"];
    if (tabBarHideShadow)
    {
      self.tabBar.clipsToBounds = [tabBarHideShadow boolValue];
    }

    if (tabBarHeight) {
	  self.tabBarHeight = tabBarHeight;

      if (!self.tabBarHeightConstraint) {
        self.tabBarHeightConstraint = [NSLayoutConstraint constraintWithItem:tabBarHolder attribute:NSLayoutAttributeHeight relatedBy:NSLayoutRelationEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:1 constant:0];
        [NSLayoutConstraint activateConstraints:@[self.tabBarHeightConstraint]];
      }
      self.tabBarHeightConstraint.constant = tabBarHeight.floatValue;
    }
  }
  
  NSMutableArray *viewControllers = [NSMutableArray array];
  NSMutableArray *tabBarItems = [NSMutableArray array];

  // go over all the tab bar items
  for (NSDictionary *tabItemLayout in children)
  {
    BOOL hasTab = [tabItemLayout[@"type"] isEqualToString:@"TabBarControllerIOS.Item"];

    // make sure the layout is valid
    if (!tabItemLayout[@"props"]) continue;
    
    // get the view controller inside
    if (!tabItemLayout[@"children"]) continue;
    if (![tabItemLayout[@"children"] isKindOfClass:[NSArray class]]) continue;
    UIViewController *viewController;
    if (hasTab)
    {
      if ([tabItemLayout[@"children"] count] < 1) continue;
      NSDictionary *childLayout = tabItemLayout[@"children"][0];
      viewController = [RCCViewController controllerWithLayout:childLayout globalProps:globalProps bridge:bridge];
    } else {
      NSDictionary *childLayout = tabItemLayout;
      viewController = [RCCViewController controllerWithLayout:childLayout globalProps:globalProps bridge:bridge];
    }
    if (!viewController) continue;

    if (hasTab)
    {
      // create the tab icon and title
      NSString *title = tabItemLayout[@"props"][@"title"];

      UIImage *iconImage = nil;
      id icon = tabItemLayout[@"props"][@"icon"];
      if (icon)
      {
        iconImage = [RCTConvert UIImage:icon];
        if (buttonColor)
        {
          iconImage = [[self image:iconImage withColor:buttonColor] imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];
        }
      }
      UIImage *iconImageSelected = nil;
      id selectedIcon = tabItemLayout[@"props"][@"selectedIcon"];
      if (selectedIcon)
      {
        iconImageSelected = [RCTConvert UIImage:selectedIcon];
      }
      else
      {
        iconImageSelected = [RCTConvert UIImage:icon];
      }

      UITabBarItem *tabBarItem = [[UITabBarItem alloc] initWithTitle:title image:iconImage tag:0];
      tabBarItem.accessibilityIdentifier = tabItemLayout[@"props"][@"testID"];
      tabBarItem.selectedImage = iconImageSelected;

	  tabBarItem.imageInsets = UIEdgeInsetsMake(-1, 0, 1, 0);

	  NSMutableDictionary *unselectedAttributes = [RCTHelpers textAttributesFromDictionary:tabsStyle withPrefix:@"tabBarText" baseFont:[UIFont systemFontOfSize:10]];
      if (!unselectedAttributes[NSForegroundColorAttributeName] && labelColor)
      {
        unselectedAttributes[NSForegroundColorAttributeName] = labelColor;
      }

      [tabBarItem setTitleTextAttributes:unselectedAttributes forState:UIControlStateNormal];

      NSMutableDictionary *selectedAttributes = [RCTHelpers textAttributesFromDictionary:tabsStyle withPrefix:@"tabBarSelectedText" baseFont:[UIFont systemFontOfSize:10]];
      if (!selectedAttributes[NSForegroundColorAttributeName] && selectedLabelColor)
      {
        selectedAttributes[NSForegroundColorAttributeName] = selectedLabelColor;
      }

      [tabBarItem setTitleTextAttributes:selectedAttributes forState:UIControlStateSelected];
	  [tabBarItem setTitlePositionAdjustment:UIOffsetMake(0, -5)];

      [tabBarItems addObject:tabBarItem];
    }

    [viewControllers addObject:viewController];
  }

  self.tabBar.items = tabBarItems.copy;

  NSUInteger leni = self.tabBar.items.count;
  CGFloat tabWidth = [UIScreen mainScreen].bounds.size.width / leni;
  for (NSUInteger i = 0; i < leni; ++i) {
	  CGFloat x = (i + 1) * tabWidth;
	  UIView *view = [[UIView alloc] initWithFrame:CGRectMake(x, 10, 0.5, 40)];
	  view.backgroundColor = [UIColor colorWithRed:0.8 green:0.8 blue:0.8 alpha:1];
	  [self.tabBar insertSubview:view atIndex:leni - i];
  }

  // replace the tabs
  self.viewControllers = viewControllers.copy;

  [self setRotation:props];
  
  return self;
}

- (void)viewWillAppear:(BOOL)animated
{
  [super viewWillAppear:animated];

  if (self.holder.subviews.count == 0) {
    RCCNavigationController *navigationController = self.viewControllers.lastObject;

    [self addChildViewController:navigationController];
    navigationController.view.translatesAutoresizingMaskIntoConstraints = NO;
    [self.holder addSubview:navigationController.view];
    [navigationController didMoveToParentViewController:self];

    NSDictionary *views = @{ @"view": navigationController.view };
    [NSLayoutConstraint activateConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|-0-[view]-0-|" options:nil metrics:nil views:views]];
    [NSLayoutConstraint activateConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|-0-[view]-0-|" options:nil metrics:nil views:views]];

    _selectedViewController = navigationController;
  }
}

- (void)performAction:(NSString*)performAction actionParams:(NSDictionary*)actionParams bridge:(RCTBridge *)bridge completion:(void (^)(void))completion
{
  if ([performAction isEqualToString:@"switchTo"])
  {
    UIViewController *viewController = nil;
    NSNumber *tabIndex = actionParams[@"tabIndex"];
    if (tabIndex)
    {
      NSUInteger i = [tabIndex unsignedIntegerValue];
      
      if ([self.viewControllers count] > i)
      {
        viewController = self.viewControllers[i];
      }
    }
    NSString *contentId = actionParams[@"contentId"];
    NSString *contentType = actionParams[@"contentType"];
    if (contentId && contentType)
    {
      viewController = [[RCCManager sharedInstance] getControllerWithId:contentId componentType:contentType];
    }
    
    if (viewController)
    {
      [self setSelectedViewController:viewController shouldSendJsEvent:NO];
    }
  }
  
  if ([performAction isEqualToString:@"setTabButton"])
  {
    UIViewController *viewController = nil;
    NSNumber *tabIndex = actionParams[@"tabIndex"];
    if (tabIndex)
    {
      NSUInteger i = [tabIndex unsignedIntegerValue];
      
      if ([self.viewControllers count] > i)
      {
        viewController = self.viewControllers[i];
      }
    }
    NSString *contentId = actionParams[@"contentId"];
    NSString *contentType = actionParams[@"contentType"];
    if (contentId && contentType)
    {
      viewController = [[RCCManager sharedInstance] getControllerWithId:contentId componentType:contentType];
    }
    
    if (viewController)
    {
      UIImage *iconImage = nil;
      id icon = actionParams[@"icon"];
      if (icon && icon != (id)[NSNull null])
      {
        iconImage = [RCTConvert UIImage:icon];
        iconImage = [[self image:iconImage withColor:self.tabBar.tintColor] imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];
        viewController.tabBarItem.image = iconImage;
      
      }
      UIImage *iconImageSelected = nil;
      id selectedIcon = actionParams[@"selectedIcon"];
      if (selectedIcon && selectedIcon != (id)[NSNull null])
      {
        iconImageSelected = [RCTConvert UIImage:selectedIcon];
        viewController.tabBarItem.selectedImage = iconImageSelected;
      }
    }
  }
  
  if ([performAction isEqualToString:@"setTabBarHidden"])
  {
    BOOL hidden = [actionParams[@"hidden"] boolValue];

	  self.tabBarHeightConstraint.constant = hidden ? 0 : self.tabBarHeight.floatValue;

    [UIView animateWithDuration: ([actionParams[@"animated"] boolValue] ? 0.45 : 0)
                          delay: 0
         usingSpringWithDamping: 0.75
          initialSpringVelocity: 0
                        options: (hidden ? UIViewAnimationOptionCurveEaseIn : UIViewAnimationOptionCurveEaseOut)
                     animations:^()
     {
		 [self.view setNeedsLayout];
		 [self.view layoutIfNeeded];
     }
                     completion:^(BOOL finished)
     {
       if (completion != nil)
       {
         completion();
       }
     }];
    return;
  }
  else if (completion != nil)
  {
    completion();
  }
}

- (void)setSelectedIndex:(NSUInteger)selectedIndex
{
  [self setSelectedIndex:selectedIndex shouldSendJsEvent:NO];
}

- (void)setSelectedIndex:(NSUInteger)selectedIndex shouldSendJsEvent:(BOOL)shouldSendJsEvent
{
  [self setSelectedViewController:self.viewControllers[selectedIndex] shouldSendJsEvent:shouldSendJsEvent];

  _selectedIndex = selectedIndex;

  if (selectedIndex < self.tabBar.items.count) {
    [self.tabBar setSelectedItem:self.tabBar.items[selectedIndex]];
  } else {
    [self.tabBar setSelectedItem:nil];
  }
}

-(void)setSelectedViewController:(__kindof UIViewController *)selectedViewController shouldSendJsEvent:(BOOL)shouldSendJsEvent
{
  UIViewController *oldController = _selectedViewController;

  _selectedViewController = selectedViewController;

  if (![oldController isEqual:selectedViewController])
  {
    [self shouldSelectViewController:selectedViewController shouldSendJsEvent:shouldSendJsEvent];

    selectedViewController.view.frame = oldController.view.bounds;
    [self addChildViewController:selectedViewController];
    [oldController willMoveToParentViewController:nil];
    selectedViewController.view.translatesAutoresizingMaskIntoConstraints = NO;
    [self.holder addSubview:selectedViewController.view];
    [selectedViewController didMoveToParentViewController:self];
    [oldController removeFromParentViewController];
    [oldController.view removeFromSuperview];

    NSDictionary *views = @{@"view" : selectedViewController.view};
    [NSLayoutConstraint activateConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|-0-[view]-0-|" options:nil metrics:nil views:views]];
    [NSLayoutConstraint activateConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|-0-[view]-0-|" options:nil metrics:nil views:views]];
  }
}

- (UIViewController *)selectedViewController {
  return self.viewControllers[self.selectedIndex];
}

+(void)sendScreenTabChangedEvent:(UIViewController*)viewController body:(NSDictionary*)body{
  [RCCTabBarController sendTabEvent:@"bottomTabSelected" controller:viewController body:body];
}

+(void)sendScreenTabPressedEvent:(UIViewController*)viewController body:(NSDictionary*)body{
  [RCCTabBarController sendTabEvent:@"bottomTabReselected" controller:viewController body:body];
}

+(void)sendTabEvent:(NSString *)event controller:(UIViewController*)viewController body:(NSDictionary*)body{
  if ([viewController.view isKindOfClass:[RCTRootView class]]){
    RCTRootView *rootView = (RCTRootView *)viewController.view;
    
    if (rootView.appProperties && rootView.appProperties[@"navigatorEventID"]) {
      NSString *navigatorID = rootView.appProperties[@"navigatorID"];
      NSString *screenInstanceID = rootView.appProperties[@"screenInstanceID"];
      
      
      NSMutableDictionary *screenDict = [NSMutableDictionary dictionaryWithDictionary:@
                                         {
                                           @"id": event,
                                           @"navigatorID": navigatorID,
                                           @"screenInstanceID": screenInstanceID
                                         }];
      
      
      if (body) {
        [screenDict addEntriesFromDictionary:body];
      }
      
      [[[RCCManager sharedInstance] getBridge].eventDispatcher sendAppEventWithName:rootView.appProperties[@"navigatorEventID"] body:screenDict];
    }
  }
  
  if ([viewController isKindOfClass:[UINavigationController class]]) {
    UINavigationController *navigationController = (UINavigationController*)viewController;
    UIViewController *topViewController = [navigationController topViewController];
    [RCCTabBarController sendTabEvent:event controller:topViewController body:body];
  }
}

- (void)tabBar:(UITabBar *)tabBar didSelectItem:(UITabBarItem *)item
{
  [self setSelectedIndex:[self.tabBar.items indexOfObject:item] shouldSendJsEvent:YES];
}

- (NSInteger)indexForScreen:(NSString *)screen
{
  __block NSInteger selectedIndex = -1;

  [self.viewControllers enumerateObjectsUsingBlock:^(UINavigationController *navigationController, NSUInteger idx, BOOL *stop)
  {
      RCTRootView *tabView = (RCTRootView *)navigationController.viewControllers.firstObject.view;
      NSString *tabScreen = tabView.moduleName;

      if ([screen isEqualToString:tabScreen]) {
        selectedIndex = idx;
        *stop = YES;
      }
  }];

  return selectedIndex;
}

- (void)showScreen:(RCCNavigationController *)controller
{
  RCTRootView *rootView = (RCTRootView *)controller.viewControllers.firstObject.view;
  NSString *newScreen = rootView.moduleName;

  NSInteger index = [self indexForScreen:newScreen];

  if (index < 0) {
	  NSMutableArray *tempControllers = self.viewControllers.mutableCopy;
	  [tempControllers removeLastObject];
	  [tempControllers addObject:controller];
	  self.viewControllers = tempControllers.copy;

	  index = self.tabBar.items.count;
  }

  self.selectedIndex = (NSUInteger)index;
}

@end
