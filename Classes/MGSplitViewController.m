//
//  MGSplitViewController.m
//  MGSplitView
//
//  Created by Matt Gemmell on 26/07/2010.
//  Copyright 2010 Instinctive Code.
//

#import "MGSplitViewController.h"
#import "MGSplitDividerView.h"
#import "MGSplitCornersView.h"

#define MG_DEFAULT_SPLIT_POSITION		320.0	// default width of master view in UISplitViewController.
#define MG_DEFAULT_SPLIT_WIDTH			1.0		// default width of split-gutter in UISplitViewController.
#define MG_DEFAULT_CORNER_RADIUS		5.0		// default corner-radius of overlapping split-inner corners on the master and detail views.
#define MG_DEFAULT_CORNER_COLOR			[UIColor blackColor]	// default color of intruding inner corners (and divider background).

#define MG_PANESPLITTER_CORNER_RADIUS	0.0		// corner-radius of split-inner corners for MGSplitViewDividerStylePaneSplitter style.
#define MG_PANESPLITTER_SPLIT_WIDTH		25.0	// width of split-gutter for MGSplitViewDividerStylePaneSplitter style.

#define MG_MIN_VIEW_WIDTH				200.0	// minimum width a view is allowed to become as a result of changing the splitPosition.

#define MG_ANIMATION_CHANGE_SPLIT_ORIENTATION	@"ChangeSplitOrientation"	// Animation ID for internal use.
#define MG_ANIMATION_CHANGE_SUBVIEWS_ORDER		@"ChangeSubviewsOrder"	// Animation ID for internal use.

@interface MGSplitViewController (MGPrivateMethods)

- (void)setup;
- (CGSize)splitViewSizeForOrientation:(UIInterfaceOrientation)theOrientation;
- (void)layoutSubviews;
- (void)layoutSubviewsWithAnimation:(BOOL)animate;
- (void)layoutSubviewsForInterfaceOrientation:(UIInterfaceOrientation)theOrientation withAnimation:(BOOL)animate;
- (BOOL)shouldShowMasterForInterfaceOrientation:(UIInterfaceOrientation)theOrientation;
- (BOOL)shouldShowMaster;
- (NSString *)nameOfInterfaceOrientation:(UIInterfaceOrientation)theOrientation;

@end


@implementation MGSplitViewController


#pragma mark -
#pragma mark Orientation helpers


- (NSString *)nameOfInterfaceOrientation:(UIInterfaceOrientation)theOrientation
{
	NSString *orientationName = nil;
	switch (theOrientation) {
		case UIInterfaceOrientationPortrait:
			orientationName = @"Portrait"; // Home button at bottom
			break;
		case UIInterfaceOrientationPortraitUpsideDown:
			orientationName = @"Portrait (Upside Down)"; // Home button at top
			break;
		case UIInterfaceOrientationLandscapeLeft:
			orientationName = @"Landscape (Left)"; // Home button on left
			break;
		case UIInterfaceOrientationLandscapeRight:
			orientationName = @"Landscape (Right)"; // Home button on right
			break;
		default:
			break;
	}
	
	return orientationName;
}


- (BOOL)isLandscape
{
	return UIInterfaceOrientationIsLandscape([[UIApplication sharedApplication] statusBarOrientation]);
}


- (BOOL)shouldShowMasterForInterfaceOrientation:(UIInterfaceOrientation)theOrientation
{
	// Returns YES if master view should be shown directly embedded in the splitview, instead of hidden in a popover.
	return ((UIInterfaceOrientationIsLandscape(theOrientation)) ? _showsMasterInLandscape : _showsMasterInPortrait);
}


- (BOOL)shouldShowMaster
{
	return [self shouldShowMasterForInterfaceOrientation:[[UIApplication sharedApplication] statusBarOrientation]];
}


- (BOOL)isShowingMaster
{
	return [self shouldShowMaster] && self.masterViewController && self.masterViewController.view && ([self.masterViewController.view superview] == self.view);
}


#pragma mark -
#pragma mark Setup and Teardown


- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
	if ((self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil])) {
    // setup called in viewDidLoad, which is more Storyboard-friendly and avoid duplication
	}
	
	return self;
}


- (id)initWithCoder:(NSCoder *)aDecoder
{
	if ((self = [super initWithCoder:aDecoder])) {
    // setup called in viewDidLoad, which is more Storyboard-friendly and avoid duplication
	}
	
	return self;
}

- (void)viewDidLoad
{
  [super viewDidLoad];
  
  [self setup];
}


- (void)setup
{
	// Configure default behaviour.
	_viewControllers = [[NSMutableArray alloc] initWithObjects:[NSNull null], [NSNull null], nil];
	_splitWidth = MG_DEFAULT_SPLIT_WIDTH;
	_showsMasterInPortrait = NO;
	_showsMasterInLandscape = YES;
	_vertical = YES;
	_masterBeforeDetail = YES;
	_splitPosition = MG_DEFAULT_SPLIT_POSITION;
	CGRect divRect = self.view.bounds;
	if ([self isVertical]) {
		divRect.origin.y = _splitPosition;
		divRect.size.height = _splitWidth;
	} else {
		divRect.origin.x = _splitPosition;
		divRect.size.width = _splitWidth;
	}
	_dividerView = [[MGSplitDividerView alloc] initWithFrame:divRect];
	_dividerView.splitViewController = self;
	_dividerView.backgroundColor = MG_DEFAULT_CORNER_COLOR;
	_dividerStyle = MGSplitViewDividerStyleThin;

    // fix for iOS 6 layout
    self.view.autoresizesSubviews = NO;
}


- (void)dealloc
{
	_delegate = nil;
	self.masterViewController = nil;
	self.detailViewController = nil;
	[self.view.subviews makeObjectsPerformSelector:@selector(removeFromSuperview)];
	
}


#pragma mark -
#pragma mark View management


- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    if (self.detailViewController)
    {
        return [self.detailViewController shouldAutorotateToInterfaceOrientation:interfaceOrientation];
    }

    return YES;
}


- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
	[self.masterViewController willRotateToInterfaceOrientation:toInterfaceOrientation duration:duration];
	[self.detailViewController willRotateToInterfaceOrientation:toInterfaceOrientation duration:duration];
}


- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation
{
	[self.masterViewController didRotateFromInterfaceOrientation:fromInterfaceOrientation];
	[self.detailViewController didRotateFromInterfaceOrientation:fromInterfaceOrientation];
}


- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation 
										 duration:(NSTimeInterval)duration
{
	[self.masterViewController willAnimateRotationToInterfaceOrientation:toInterfaceOrientation duration:duration];
	[self.detailViewController willAnimateRotationToInterfaceOrientation:toInterfaceOrientation duration:duration];
	
	// Re-tile views.
	[self layoutSubviewsForInterfaceOrientation:toInterfaceOrientation withAnimation:YES];
}


- (void)willAnimateFirstHalfOfRotationToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
	[self.masterViewController willAnimateFirstHalfOfRotationToInterfaceOrientation:toInterfaceOrientation duration:duration];
	[self.detailViewController willAnimateFirstHalfOfRotationToInterfaceOrientation:toInterfaceOrientation duration:duration];
}


- (void)didAnimateFirstHalfOfRotationToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation
{
	[self.masterViewController didAnimateFirstHalfOfRotationToInterfaceOrientation:toInterfaceOrientation];
	[self.detailViewController didAnimateFirstHalfOfRotationToInterfaceOrientation:toInterfaceOrientation];
}


- (void)willAnimateSecondHalfOfRotationFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation duration:(NSTimeInterval)duration
{
	[self.masterViewController willAnimateSecondHalfOfRotationFromInterfaceOrientation:fromInterfaceOrientation duration:duration];
	[self.detailViewController willAnimateSecondHalfOfRotationFromInterfaceOrientation:fromInterfaceOrientation duration:duration];
}


- (CGSize)splitViewSizeForOrientation:(UIInterfaceOrientation)theOrientation
{
	UIScreen *screen = [UIScreen mainScreen];
	CGRect fullScreenRect = screen.bounds; // always implicitly in Portrait orientation.
	CGRect appFrame = screen.applicationFrame;
	
	// Find status bar height by checking which dimension of the applicationFrame is narrower than screen bounds.
	// Little bit ugly looking, but it'll still work even if they change the status bar height in future.
	float statusBarHeight = MAX((fullScreenRect.size.width - appFrame.size.width), (fullScreenRect.size.height - appFrame.size.height));
    
    // In iOS 7 the status bar is transparent, so don't adjust for it.
    if (NSFoundationVersionNumber >= NSFoundationVersionNumber_iOS_7_0)
        statusBarHeight = 0;
	
	float navigationBarHeight = 0;
	if ((self.navigationController)&&(!self.navigationController.navigationBarHidden)) {
		navigationBarHeight = self.navigationController.navigationBar.frame.size.height;
	}
	
	// Initially assume portrait orientation.
	float width = fullScreenRect.size.width;
	float height = fullScreenRect.size.height;
	
  // Correct for orientation (only for iOS7.1 and earlier, since iOS8 it will do it automatically).
  if (NSFoundationVersionNumber <= NSFoundationVersionNumber_iOS_7_1 && UIInterfaceOrientationIsLandscape(theOrientation)) {
		width = height;
		height = fullScreenRect.size.width;
	}
	
	// Account for status bar, which always subtracts from the height (since it's always at the top of the screen).
	height -= statusBarHeight;
	height -= navigationBarHeight;
	
	return CGSizeMake(width, height);
}


- (void)layoutSubviewsForInterfaceOrientation:(UIInterfaceOrientation)theOrientation withAnimation:(BOOL)animate
{
	// Layout the master, detail and divider views appropriately, adding/removing subviews as needed.
	// First obtain relevant geometry.
	CGSize fullSize = [self splitViewSizeForOrientation:theOrientation];
	float width = fullSize.width;
	float height = fullSize.height;
	
	if (NO) { // Just for debugging.
		NSLog(@"Target orientation is %@, dimensions will be %.0f x %.0f", 
			  [self nameOfInterfaceOrientation:theOrientation], width, height);
	}
	
	// Layout the master, divider and detail views.
	CGRect newFrame = CGRectMake(0, 0, width, height);
	UIViewController *controller;
	UIView *theView;
	BOOL shouldShowMaster = [self shouldShowMasterForInterfaceOrientation:theOrientation];
	BOOL masterFirst = [self isMasterBeforeDetail];
  
	if ([self isVertical]) {
		// Master on left, detail on right (or vice versa).
		CGRect masterRect, dividerRect, detailRect;
		if (masterFirst) {
			if (!shouldShowMaster) {
				// Move off-screen.
				newFrame.origin.x -= (_splitPosition + _splitWidth);
			}
			
			newFrame.size.width = _splitPosition;
			masterRect = newFrame;
			
			newFrame.origin.x += newFrame.size.width;
			newFrame.size.width = _splitWidth;
			dividerRect = newFrame;
			
			newFrame.origin.x += newFrame.size.width;
			newFrame.size.width = width - newFrame.origin.x;
			detailRect = newFrame;
			
		} else {
			if (!shouldShowMaster) {
				// Move off-screen.
				newFrame.size.width += (_splitPosition + _splitWidth);
			}
			
			newFrame.size.width -= (_splitPosition + _splitWidth);
			detailRect = newFrame;
			
			newFrame.origin.x += newFrame.size.width;
			newFrame.size.width = _splitWidth;
			dividerRect = newFrame;
			
			newFrame.origin.x += newFrame.size.width;
			newFrame.size.width = _splitPosition;
			masterRect = newFrame;
		}
		
		// Position master.
		controller = self.masterViewController;
		if (controller && [controller isKindOfClass:[UIViewController class]])  {
			theView = controller.view;
			if (theView) {
				theView.frame = masterRect;
				if (!theView.superview) {
					[controller viewWillAppear:NO];
					[self.view addSubview:theView];
					[controller viewDidAppear:NO];
				}
			}
		}
		
		// Position divider.
		theView = _dividerView;
		theView.frame = dividerRect;
		if (!theView.superview) {
			[self.view addSubview:theView];
		}
		
		// Position detail.
		controller = self.detailViewController;
		if (controller && [controller isKindOfClass:[UIViewController class]])  {
			theView = controller.view;
			if (theView) {
				theView.frame = detailRect;
				if (!theView.superview) {
					[self.view insertSubview:theView aboveSubview:self.masterViewController.view];
				} else {
					[self.view bringSubviewToFront:theView];
				}
			}
		}
		
	} else {
		// Master above, detail below (or vice versa).
		CGRect masterRect, dividerRect, detailRect;
		if (masterFirst) {
			if (!shouldShowMaster) {
				// Move off-screen.
				newFrame.origin.y -= (_splitPosition + _splitWidth);
			}
			
			newFrame.size.height = _splitPosition;
			masterRect = newFrame;
			
			newFrame.origin.y += newFrame.size.height;
			newFrame.size.height = _splitWidth;
			dividerRect = newFrame;
			
			newFrame.origin.y += newFrame.size.height;
			newFrame.size.height = height - newFrame.origin.y;
			detailRect = newFrame;
			
		} else {
			if (!shouldShowMaster) {
				// Move off-screen.
				newFrame.size.height += (_splitPosition + _splitWidth);
			}
			
			newFrame.size.height -= (_splitPosition + _splitWidth);
			detailRect = newFrame;
			
			newFrame.origin.y += newFrame.size.height;
			newFrame.size.height = _splitWidth;
			dividerRect = newFrame;
			
			newFrame.origin.y += newFrame.size.height;
			newFrame.size.height = _splitPosition;
			masterRect = newFrame;
		}
		
		// Position master.
		controller = self.masterViewController;
		if (controller && [controller isKindOfClass:[UIViewController class]])  {
			theView = controller.view;
			if (theView) {
				theView.frame = masterRect;
				if (!theView.superview) {
					[controller viewWillAppear:NO];
					[self.view addSubview:theView];
					[controller viewDidAppear:NO];
				}
			}
		}
		
		// Position divider.
		theView = _dividerView;
		theView.frame = dividerRect;
		if (!theView.superview) {
			[self.view addSubview:theView];
		}
		
		// Position detail.
		controller = self.detailViewController;
		if (controller && [controller isKindOfClass:[UIViewController class]])  {
			theView = controller.view;
			if (theView) {
				theView.frame = detailRect;
				if (!theView.superview) {
					[self.view insertSubview:theView aboveSubview:self.masterViewController.view];
				} else {
					[self.view bringSubviewToFront:theView];
				}
			}
		}
	}
}


- (void)layoutSubviewsWithAnimation:(BOOL)animate
{
	[self layoutSubviewsForInterfaceOrientation:self.interfaceOrientation withAnimation:animate];
}


- (void)layoutSubviews
{
	[self layoutSubviewsForInterfaceOrientation:self.interfaceOrientation withAnimation:YES];
}


- (void)viewWillAppear:(BOOL)animated
{
	[super viewWillAppear:animated];
	
	if ([self isShowingMaster]) {
		[self.masterViewController viewWillAppear:animated];
	}
	[self.detailViewController viewWillAppear:animated];
}


- (void)viewDidAppear:(BOOL)animated
{
	[super viewDidAppear:animated];
	
	if ([self isShowingMaster]) {
		[self.masterViewController viewDidAppear:animated];
	}
	[self.detailViewController viewDidAppear:animated];
	[self layoutSubviews];
}


- (void)viewWillDisappear:(BOOL)animated
{
	[super viewWillDisappear:animated];
	
	if ([self isShowingMaster]) {
		[self.masterViewController viewWillDisappear:animated];
	}
	[self.detailViewController viewWillDisappear:animated];
}


- (void)viewDidDisappear:(BOOL)animated
{
	[super viewDidDisappear:animated];
	
	if ([self isShowingMaster]) {
		[self.masterViewController viewDidDisappear:animated];
	}
	[self.detailViewController viewDidDisappear:animated];
}

#pragma mark -
#pragma mark IB Actions


- (IBAction)toggleSplitOrientation:(id)sender
{
	BOOL showingMaster = [self isShowingMaster];
	if (showingMaster) {
		[UIView beginAnimations:MG_ANIMATION_CHANGE_SPLIT_ORIENTATION context:nil];
		[UIView setAnimationDelegate:self];
	}
	self.vertical = (!self.vertical);
	if (showingMaster) {
		[UIView commitAnimations];
	}
}


- (IBAction)toggleMasterBeforeDetail:(id)sender
{
	BOOL showingMaster = [self isShowingMaster];
	if (showingMaster) {
		[UIView beginAnimations:MG_ANIMATION_CHANGE_SUBVIEWS_ORDER context:nil];
		[UIView setAnimationDelegate:self];
	}
	self.masterBeforeDetail = (!self.masterBeforeDetail);
	if (showingMaster) {
		[UIView commitAnimations];
	}
}


- (IBAction)toggleMasterView:(id)sender
{
	if (![self isShowingMaster]) {
		// We're about to show the master view. Ensure it's in place off-screen to be animated in.
		[self layoutSubviews];
	}
	
	// This action functions on the current primary orientation; it is independent of the other primary orientation.
	[UIView beginAnimations:@"toggleMaster" context:nil];
	if (self.isLandscape) {
		self.showsMasterInLandscape = !_showsMasterInLandscape;
	} else {
		self.showsMasterInPortrait = !_showsMasterInPortrait;
	}
	[UIView commitAnimations];
}

#pragma mark -
#pragma mark Accessors and properties


- (id)delegate
{
	return _delegate;
}


- (void)setDelegate:(id <MGSplitViewControllerDelegate>)newDelegate
{
	if (newDelegate != _delegate && 
		(!newDelegate || [(NSObject *)newDelegate conformsToProtocol:@protocol(MGSplitViewControllerDelegate)])) {
		_delegate = newDelegate;
	}
}


- (BOOL)showsMasterInPortrait
{
	return _showsMasterInPortrait;
}


- (void)setShowsMasterInPortrait:(BOOL)flag
{
	if (flag != _showsMasterInPortrait) {
		_showsMasterInPortrait = flag;
		
		if (![self isLandscape]) { // i.e. if this will cause a visual change.
			// Rearrange views.
			[self layoutSubviews];
		}
	}
}


- (BOOL)showsMasterInLandscape
{
	return _showsMasterInLandscape;
}


- (void)setShowsMasterInLandscape:(BOOL)flag
{
	if (flag != _showsMasterInLandscape) {
		_showsMasterInLandscape = flag;
		
		if ([self isLandscape]) { // i.e. if this will cause a visual change.
			// Rearrange views.
			[self layoutSubviews];
		}
	}
}


- (BOOL)isVertical
{
	return _vertical;
}


- (void)setVertical:(BOOL)flag
{
	if (flag != _vertical) {
		_vertical = flag;
		
		// Inform delegate.
		if (_delegate && [_delegate respondsToSelector:@selector(splitViewController:willChangeSplitOrientationToVertical:)]) {
			[_delegate splitViewController:self willChangeSplitOrientationToVertical:_vertical];
		}
		
		[self layoutSubviews];
	}
}


- (BOOL)isMasterBeforeDetail
{
	return _masterBeforeDetail;
}


- (void)setMasterBeforeDetail:(BOOL)flag
{
	if (flag != _masterBeforeDetail) {
		_masterBeforeDetail = flag;
		
		if ([self isShowingMaster]) {
			[self layoutSubviews];
		}
	}
}


- (float)splitPosition
{
	return _splitPosition;
}


- (void)setSplitPosition:(float)posn
{
	// Check to see if delegate wishes to constrain the position.
	float newPosn = posn;
	BOOL constrained = NO;
	CGSize fullSize = [self splitViewSizeForOrientation:self.interfaceOrientation];
	if (_delegate && [_delegate respondsToSelector:@selector(splitViewController:constrainSplitPosition:splitViewSize:)]) {
		newPosn = [_delegate splitViewController:self constrainSplitPosition:newPosn splitViewSize:fullSize];
		constrained = YES; // implicitly trust delegate's response.
		
	} else {
		// Apply default constraints if delegate doesn't wish to participate.
		float minPos = MG_MIN_VIEW_WIDTH;
		float maxPos = ((_vertical) ? fullSize.width : fullSize.height) - (MG_MIN_VIEW_WIDTH + _splitWidth);
		constrained = (newPosn != _splitPosition && newPosn >= minPos && newPosn <= maxPos);
	}
	
	if (constrained) {
		_splitPosition = newPosn;
		
		// Inform delegate.
		if (_delegate && [_delegate respondsToSelector:@selector(splitViewController:willMoveSplitToPosition:)]) {
			[_delegate splitViewController:self willMoveSplitToPosition:_splitPosition];
		}
		
		if ([self isShowingMaster]) {
			[self layoutSubviews];
		}
	}
}


- (void)setSplitPosition:(float)posn animated:(BOOL)animate
{
	BOOL shouldAnimate = (animate && [self isShowingMaster]);
	if (shouldAnimate) {
		[UIView beginAnimations:@"SplitPosition" context:nil];
	}
	[self setSplitPosition:posn];
	if (shouldAnimate) {
		[UIView commitAnimations];
	}
}


- (float)splitWidth
{
	return _splitWidth;
}


- (void)setSplitWidth:(float)width
{
	if (width != _splitWidth && width >= 0) {
		_splitWidth = width;
		if ([self isShowingMaster]) {
			[self layoutSubviews];
		}
	}
}


- (NSArray *)viewControllers
{
	return [_viewControllers copy];
}


- (void)setViewControllers:(NSArray *)controllers
{
	if (controllers != _viewControllers) {
		for (UIViewController *controller in _viewControllers) {
			if ([controller isKindOfClass:[UIViewController class]]) {
				[controller.view removeFromSuperview];
			}
		}
		_viewControllers = [[NSMutableArray alloc] initWithCapacity:2];
		if (controllers && [controllers count] >= 2) {
			self.masterViewController = [controllers objectAtIndex:0];
			self.detailViewController = [controllers objectAtIndex:1];
		} else {
			NSLog(@"Error: %@ requires 2 view-controllers. (%@)", NSStringFromClass([self class]), NSStringFromSelector(_cmd));
		}
		
		[self layoutSubviews];
	}
}


- (UIViewController *)masterViewController
{
	if (_viewControllers && [_viewControllers count] > 0) {
		UIViewController *controller = (UIViewController *)[_viewControllers objectAtIndex:0];
		if ([controller isKindOfClass:[UIViewController class]]) {
			return controller;
		}
	}
	
	return nil;
}


- (void)setMasterViewController:(UIViewController *)master
{
	if (!_viewControllers) {
		_viewControllers = [[NSMutableArray alloc] initWithCapacity:2];
	}
	
	NSObject *newMaster = master;
	if (!newMaster) {
		newMaster = [NSNull null];
	}
	
	BOOL changed = YES;
	if ([_viewControllers count] > 0) {
		if ([_viewControllers objectAtIndex:0] == newMaster) {
			changed = NO;
		} else {
			[_viewControllers replaceObjectAtIndex:0 withObject:newMaster];
		}
		
	} else {
		[_viewControllers addObject:newMaster];
	}
	
	if (changed) {
		[self layoutSubviews];
	}
}


- (UIViewController *)detailViewController
{
	if (_viewControllers && [_viewControllers count] > 1) {
		UIViewController *controller = (UIViewController *)[_viewControllers objectAtIndex:1];
		if ([controller isKindOfClass:[UIViewController class]]) {
			return controller;
		}
	}
	
	return nil;
}


- (void)setDetailViewController:(UIViewController *)detail
{
	if (!_viewControllers) {
		_viewControllers = [[NSMutableArray alloc] initWithCapacity:2];
		[_viewControllers addObject:[NSNull null]];
	}
	
	BOOL changed = YES;
	if ([_viewControllers count] > 1) {
		if ([_viewControllers objectAtIndex:1] == detail) {
			changed = NO;
		} else {
			[_viewControllers replaceObjectAtIndex:1 withObject:detail];
		}
		
	} else {
		[_viewControllers addObject:detail];
	}
	
	if (changed) {
		[self layoutSubviews];
	}
}


- (MGSplitDividerView *)dividerView
{
	return _dividerView;
}


- (void)setDividerView:(MGSplitDividerView *)divider
{
	if (divider != _dividerView) {
		[_dividerView removeFromSuperview];
		_dividerView = divider;
		_dividerView.splitViewController = self;
		_dividerView.backgroundColor = MG_DEFAULT_CORNER_COLOR;
		if ([self isShowingMaster]) {
			[self layoutSubviews];
		}
	}
}


- (BOOL)allowsDraggingDivider
{
	if (_dividerView) {
		return _dividerView.allowsDragging;
	}
	
	return NO;
}


- (void)setAllowsDraggingDivider:(BOOL)flag
{
	if (self.allowsDraggingDivider != flag && _dividerView) {
		_dividerView.allowsDragging = flag;
	}
}


- (MGSplitViewDividerStyle)dividerStyle
{
	return _dividerStyle;
}


- (void)setDividerStyle:(MGSplitViewDividerStyle)newStyle
{
	// We don't check to see if newStyle equals _dividerStyle, because it's a meta-setting.
	// Aspects could have been changed since it was set.
	_dividerStyle = newStyle;
	
	// Reconfigure general appearance and behaviour.
	float cornerRadius = 0.0f;
	if (_dividerStyle == MGSplitViewDividerStyleThin) {
		cornerRadius = MG_DEFAULT_CORNER_RADIUS;
		_splitWidth = MG_DEFAULT_SPLIT_WIDTH;
		self.allowsDraggingDivider = NO;
		
	} else if (_dividerStyle == MGSplitViewDividerStylePaneSplitter) {
		cornerRadius = MG_PANESPLITTER_CORNER_RADIUS;
		_splitWidth = MG_PANESPLITTER_SPLIT_WIDTH;
		self.allowsDraggingDivider = YES;
	}
	
	// Update divider and corners.
	[_dividerView setNeedsDisplay];
	
	// Layout all views.
	[self layoutSubviews];
}


- (void)setDividerStyle:(MGSplitViewDividerStyle)newStyle animated:(BOOL)animate
{
	BOOL shouldAnimate = (animate && [self isShowingMaster]);
	if (shouldAnimate) {
		[UIView beginAnimations:@"DividerStyle" context:nil];
	}
	[self setDividerStyle:newStyle];
	if (shouldAnimate) {
		[UIView commitAnimations];
	}
}


@synthesize showsMasterInPortrait;
@synthesize showsMasterInLandscape;
@synthesize vertical;
@synthesize delegate;
@synthesize viewControllers = _viewControllers;
@synthesize masterViewController;
@synthesize detailViewController;
@synthesize dividerView = _dividerView;
@synthesize splitPosition;
@synthesize splitWidth;
@synthesize allowsDraggingDivider;
@synthesize dividerStyle;

@end
