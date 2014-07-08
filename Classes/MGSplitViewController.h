//
//  MGSplitViewController.h
//  MGSplitView
//
//  Created by Matt Gemmell on 26/07/2010.
//  Copyright 2010 Instinctive Code.
//

#import <UIKit/UIKit.h>

typedef enum _MGSplitViewDividerStyle {
	// These names have been chosen to be conceptually similar to those of NSSplitView on Mac OS X.
	MGSplitViewDividerStyleThin			= 0, // Thin divider, like UISplitViewController (default).
	MGSplitViewDividerStylePaneSplitter	= 1  // Thick divider, drawn with a grey gradient and a grab-strip.
} MGSplitViewDividerStyle;

@class MGSplitDividerView;
@protocol MGSplitViewControllerDelegate;
@interface MGSplitViewController : UIViewController {
	BOOL _showsMasterInPortrait;
	BOOL _showsMasterInLandscape;
	float _splitWidth;
	id _delegate;
	BOOL _vertical;
	BOOL _masterBeforeDetail;
	NSMutableArray *_viewControllers;
	MGSplitDividerView *_dividerView; // View that draws the divider between the master and detail views.
	float _splitPosition;
	MGSplitViewDividerStyle _dividerStyle; // Meta-setting which configures several aspects of appearance and behaviour.
}

@property (nonatomic, unsafe_unretained) IBOutlet id <MGSplitViewControllerDelegate> delegate;
@property (nonatomic, assign) BOOL showsMasterInPortrait; // applies to both portrait orientations (default NO)
@property (nonatomic, assign) BOOL showsMasterInLandscape; // applies to both landscape orientations (default YES)
@property (nonatomic, assign, getter=isVertical) BOOL vertical; // if NO, split is horizontal, i.e. master above detail (default YES)
@property (nonatomic, assign, getter=isMasterBeforeDetail) BOOL masterBeforeDetail; // if NO, master view is below/right of detail (default YES)
@property (nonatomic, assign) float splitPosition; // starting position of split in pixels, relative to top/left (depending on .isVertical setting) if masterBeforeDetail is YES, else relative to bottom/right.
@property (nonatomic, assign) float splitWidth; // width of split in pixels.
@property (nonatomic, assign) BOOL allowsDraggingDivider; // whether to let the user drag the divider to alter the split position (default NO).

@property (nonatomic, copy) NSArray *viewControllers; // array of UIViewControllers; master is at index 0, detail is at index 1.
@property (nonatomic, strong) IBOutlet UIViewController *masterViewController; // convenience.
@property (nonatomic, strong) IBOutlet UIViewController *detailViewController; // convenience.
@property (nonatomic, strong) MGSplitDividerView *dividerView; // the view which draws the divider/split between master and detail.
@property (nonatomic, assign) MGSplitViewDividerStyle dividerStyle; // style (and behaviour) of the divider between master and detail.

@property (nonatomic, readonly, getter=isLandscape) BOOL landscape; // returns YES if this view controller is in either of the two Landscape orientations, else NO.

// Actions
- (IBAction)toggleSplitOrientation:(id)sender; // toggles split axis between vertical (left/right; default) and horizontal (top/bottom).
- (IBAction)toggleMasterBeforeDetail:(id)sender; // toggles position of master view relative to detail view.
- (IBAction)toggleMasterView:(id)sender; // toggles display of the master view in the current orientation.

// Conveniences for you, because I care.
- (BOOL)isShowingMaster;
- (void)setSplitPosition:(float)posn animated:(BOOL)animate; // Allows for animation of splitPosition changes. The property's regular setter is not animated.
/* Note:	splitPosition is the width (in a left/right split, or height in a top/bottom split) of the master view.
			It is relative to the appropriate side of the splitView, which can be any of the four sides depending on the values in isMasterBeforeDetail and isVertical:
				isVertical = YES, isMasterBeforeDetail = YES: splitPosition is relative to the LEFT edge. (Default)
				isVertical = YES, isMasterBeforeDetail = NO: splitPosition is relative to the RIGHT edge.
 				isVertical = NO, isMasterBeforeDetail = YES: splitPosition is relative to the TOP edge.
 				isVertical = NO, isMasterBeforeDetail = NO: splitPosition is relative to the BOTTOM edge.

			This implementation was chosen so you don't need to recalculate equivalent splitPositions if the user toggles masterBeforeDetail themselves.
 */
- (void)setDividerStyle:(MGSplitViewDividerStyle)newStyle animated:(BOOL)animate; // Allows for animation of dividerStyle changes. The property's regular setter is not animated.

- (void)layoutSubviewsForInterfaceOrientation:(UIInterfaceOrientation)theOrientation withAnimation:(BOOL)animate;

@end


@protocol MGSplitViewControllerDelegate

@optional

// Called when the split orientation will change (from vertical to horizontal, or vice versa).
- (void)splitViewController:(MGSplitViewController*)svc willChangeSplitOrientationToVertical:(BOOL)isVertical;

// Called when split position will change to the given pixel value (relative to left if split is vertical, or to top if horizontal).
- (void)splitViewController:(MGSplitViewController*)svc willMoveSplitToPosition:(float)position;

// Called before split position is changed to the given pixel value (relative to left if split is vertical, or to top if horizontal).
// Note that viewSize is the current size of the entire split-view; i.e. the area enclosing the master, divider and detail views.
- (float)splitViewController:(MGSplitViewController *)svc constrainSplitPosition:(float)proposedPosition splitViewSize:(CGSize)viewSize;

@end
