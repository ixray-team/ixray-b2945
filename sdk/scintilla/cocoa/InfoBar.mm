
/**
 * Scintilla source code edit control
 * InfoBar.mm - Implements special info bar with zoom info, caret position etc. to be used with
 *              ScintillaView.
 *
 * Mike Lischke <mlischke@sun.com>
 *
 * Copyright 2009 Sun Microsystems, Inc. All rights reserved.
 * This file is dual licensed under LGPL v2.1 and the Scintilla license (http://www.scintilla.org/License.txt).
 */

#import "InfoBar.h"

//--------------------------------------------------------------------------------------------------

@implementation VerticallyCenteredTextFieldCell

// Inspired by code from Daniel Jalkut, Red Sweater Software.

- (NSRect) drawingRectForBounds: (NSRect) theRect
{
	// Get the parent's idea of where we should draw
	NSRect newRect = [super drawingRectForBounds: theRect];
  
	// When the text field is being edited or selected, we have to turn off the magic because it
  // screws up the configuration of the field editor. We sneak around this by intercepting
  // selectWithFrame and editWithFrame and sneaking a reduced, centered rect in at the last minute.
	if (mIsEditingOrSelecting == NO)
	{
		// Get our ideal size for current text
		NSSize textSize = [self cellSizeForBounds: theRect];
    
		// Center that in the proposed rect
		float heightDelta = newRect.size.height - textSize.height;	
		if (heightDelta > 0)
		{
			newRect.size.height -= heightDelta;
			newRect.origin.y += ceil(heightDelta / 2);
		}
	}
	
	return newRect;
}

//--------------------------------------------------------------------------------------------------

- (void) selectWithFrame: (NSRect) aRect inView: (NSView*) controlView editor: (NSText*) textObj 
                delegate:(id) anObject start: (int) selStart length: (int) selLength
{
	aRect = [self drawingRectForBounds: aRect];
	mIsEditingOrSelecting = YES;	
	[super selectWithFrame: aRect
                  inView: controlView
                  editor: textObj
                delegate: anObject
                   start: selStart
                  length: selLength];
	mIsEditingOrSelecting = NO;
}

//--------------------------------------------------------------------------------------------------

- (void) editWithFrame: (NSRect) aRect inView: (NSView*) controlView editor: (NSText*) textObj
              delegate: (id) anObject event: (NSEvent*) theEvent
{	
	aRect = [self drawingRectForBounds: aRect];
	mIsEditingOrSelecting = YES;
	[super editWithFrame: aRect
                inView: controlView
                editor: textObj
              delegate: anObject
                 event: theEvent];
	mIsEditingOrSelecting = NO;
}

@end

//--------------------------------------------------------------------------------------------------

@implementation InfoBar

- (id) initWithFrame: (NSRect) frame
{
  self = [super initWithFrame: frame];
  if (self)
  {
    NSBundle* bundle = [NSBundle bundleForClass: [InfoBar class]];
    
    NSString* path = [bundle pathForResource: @"info_bar_bg" ofType: @"png" inDirectory: nil];
    mBackground = [[[NSImage alloc] initWithContentsOfFile: path] retain];
    if (![mBackground isValid])
      NSLog(@"Background image for info bar is invalid.");

    mScaleFactor = 1.0;
    mCurrentCaretX = 0;
    mCurrentCaretY = 0;
    [self createItems];
  }
  return self;
}

//--------------------------------------------------------------------------------------------------

/**
 * Called by a connected compontent (usually the info bar) if something changed there.
 *
 * @param type The type of the notification.
 * @param message Carries the new status message if the type is a status message change.
 * @param location Carries the new location (e.g. caret) if the type is a caret change or similar type.
 * @param location Carries the new zoom value if the type is a zoom change.
 */
- (void) notify: (NotificationType) type message: (NSString*) message location: (NSPoint) location
  value: (float) value
{
  switch (type)
  {
    case IBNZoomChanged:
      [self setScaleFactor: value adjustPopup: YES];
      break;
    case IBNCaretChanged:
      [self setCaretPosition: location];
      break;
    case IBNStatusChanged:
      [mStatusTextLabel setStringValue: message];
      break;
  }
}

//--------------------------------------------------------------------------------------------------

/**
 * Used to set a protocol object we can use to send change notifications to.
 */
- (void) setCallback: (id <InfoBarCommunicator>) callback
{
  mCallback = callback;
}

//--------------------------------------------------------------------------------------------------

static NSString *DefaultScaleMenuLabels[] = {
  @"20%", @"30%", @"50%", @"75%", @"100%", @"130%", @"160%", @"200%", @"250%", @"300%"
};
static float DefaultScaleMenuFactors[] = {
  0.2, 0.3, 0.5, 0.75, 1.0, 1.3, 1.6, 2.0, 2.5, 3.0
};
static unsigned DefaultScaleMenuSelectedItemIndex = 4;
static float BarFontSize = 10.0;

- (void) createItems
{
  // 1) The zoom popup.
  unsigned numberOfDefaultItems = sizeof(DefaultScaleMenuLabels) / sizeof(NSString *);
  
  // Create the popup button.
  mZoomPopup = [[NSPopUpButton allocWithZone:[self zone]] initWithFrame: NSMakeRect(0.0, 0.0, 1.0, 1.0) pullsDown: NO];
  
  // No border or background please.
  [[mZoomPopup cell] setBordered: NO];
  [[mZoomPopup cell] setArrowPosition: NSPopUpArrowAtBottom];
  
  // Fill it.
  for (unsigned count = 0; count < numberOfDefaultItems; count++)
  {
    [mZoomPopup addItemWithTitle: NSLocalizedStringFromTable(DefaultScaleMenuLabels[count], @"ZoomValues", nil)];
    id currentItem = [mZoomPopup itemAtIndex: count];
    if (DefaultScaleMenuFactors[count] != 0.0)
      [currentItem setRepresentedObject: [NSNumber numberWithFloat: DefaultScaleMenuFactors[count]]];
  }
  [mZoomPopup selectItemAtIndex: DefaultScaleMenuSelectedItemIndex];
  
  // Hook it up.
  [mZoomPopup setTarget: self];
  [mZoomPopup setAction: @selector(zoomItemAction:)];
  
  // Set a suitable font.
  [mZoomPopup setFont: [NSFont menuBarFontOfSize: BarFontSize]];
  
  // Make sure the popup is big enough to fit the cells.
  [mZoomPopup sizeToFit];
  
  // Don't let it become first responder
  [mZoomPopup setRefusesFirstResponder: YES];
  
  // put it in the scrollview.
  [self addSubview: mZoomPopup];
  [mZoomPopup release];
  
  // 2) The caret position label.
  [NSTextField setCellClass: [VerticallyCenteredTextFieldCell class]];
  
  mCaretPositionLabel = [[NSTextField alloc] initWithFrame: NSMakeRect(0.0, 0.0, 50.0, 1.0)];
  [mCaretPositionLabel setBezeled: NO];
  [mCaretPositionLabel setBordered: NO];
  [mCaretPositionLabel setEditable: NO];
  [mCaretPositionLabel setSelectable: NO];
  [mCaretPositionLabel setDrawsBackground: NO];
  [mCaretPositionLabel setFont: [NSFont menuBarFontOfSize: BarFontSize]];

  NSTextFieldCell* cell = [mCaretPositionLabel cell];
  [cell setPlaceholderString: @"0:0"];
  [cell setAlignment: NSCenterTextAlignment];

  [self addSubview: mCaretPositionLabel];
  [mCaretPositionLabel release];
  
  // 3) The status text.
  mStatusTextLabel = [[NSTextField alloc] initWithFrame: NSMakeRect(0.0, 0.0, 1.0, 1.0)];
  [mStatusTextLabel setBezeled: NO];
  [mStatusTextLabel setBordered: NO];
  [mStatusTextLabel setEditable: NO];
  [mStatusTextLabel setSelectable: NO];
  [mStatusTextLabel setDrawsBackground: NO];
  [mStatusTextLabel setFont: [NSFont menuBarFontOfSize: BarFontSize]];

  cell = [mStatusTextLabel cell];
  [cell setPlaceholderString: @"Default status text"];

  [self addSubview: mStatusTextLabel];
  [mStatusTextLabel release];
}

//--------------------------------------------------------------------------------------------------

- (void) dealloc
{
  [mBackground release];
  [super dealloc];
}

//--------------------------------------------------------------------------------------------------

/**
 * Fill the background.
 */
- (void) drawRect: (NSRect) rect
{
  // Since the background is seamless, we don't need to take care for the proper offset.
  // Simply tile the background over the invalid rectangle.
  NSPoint target = {rect.origin.x, 0};
  while (target.x < rect.origin.x + rect.size.width)
  {
    [mBackground drawAtPoint: target fromRect: NSZeroRect operation: NSCompositeCopy fraction: 1];
    target.x += mBackground.size.width;
  }
  
  // Draw separator lines between items.
  NSRect verticalLineRect;
  float component = 190.0 / 255.0;
  NSColor* lineColor = [NSColor colorWithDeviceRed: component green: component blue: component alpha: 1];
  
  if (mDisplayMask & IBShowZoom)
  {
    verticalLineRect = [mZoomPopup frame];
    verticalLineRect.origin.x += verticalLineRect.size.width + 1.0;
    verticalLineRect.size.width = 1.0;
    if (NSIntersectsRect(rect, verticalLineRect))
    {
      [lineColor set];
      NSRectFill(verticalLineRect);
    }
  }
  
  if (mDisplayMask & IBShowCaretPosition)
  {
    verticalLineRect = [mCaretPositionLabel frame];
    verticalLineRect.origin.x += verticalLineRect.size.width + 1.0;
    verticalLineRect.size.width = 1.0;
    if (NSIntersectsRect(rect, verticalLineRect))
    {
      [lineColor set];
      NSRectFill(verticalLineRect);
    }
  }
}

//--------------------------------------------------------------------------------------------------

- (BOOL) isOpaque
{
  return YES;
}

//--------------------------------------------------------------------------------------------------

/**
 * Used to reposition our content depending on the size of the view.
 */
- (void) setFrame: (NSRect) newFrame
{
  [super setFrame: newFrame];
  [self layout];
}

//--------------------------------------------------------------------------------------------------

- (void) layout
{
  NSRect currentBounds = {0, 0, 0, [self frame].size.height};
  if (mDisplayMask & IBShowZoom)
  {
    [mZoomPopup setHidden: NO];
    currentBounds.size.width = [mZoomPopup frame].size.width;
    [mZoomPopup setFrame: currentBounds];
    currentBounds.origin.x += currentBounds.size.width + 1; // Add 1 for the separator.
  }
  else
    [mZoomPopup setHidden: YES];

  if (mDisplayMask & IBShowCaretPosition)
  {
    [mCaretPositionLabel setHidden: NO];
    currentBounds.size.width = [mCaretPositionLabel frame].size.width;
    [mCaretPositionLabel setFrame: currentBounds];
    currentBounds.origin.x += currentBounds.size.width + 1;
  }
  else
    [mCaretPositionLabel setHidden: YES];

  if (mDisplayMask & IBShowStatusText)
  {
    // The status text always takes the rest of the available space.
    [mStatusTextLabel setHidden: NO];
    currentBounds.size.width = [self frame].size.width - currentBounds.origin.x;
    [mStatusTextLabel setFrame: currentBounds];
  }
  else
    [mStatusTextLabel setHidden: YES];
}

//--------------------------------------------------------------------------------------------------

/**
 * Used to switch the visible parts of the info bar.
 *
 * @param display Bitwise ORed IBDisplay values which determine what to show on the bar.
 */
- (void) setDisplay: (IBDisplay) display
{
  if (mDisplayMask != display)
  {
    mDisplayMask = display;
    [self layout];
    [self needsDisplay];
  }  
}

//--------------------------------------------------------------------------------------------------

/**
 * Handler for selection changes in the zoom menu.
 */
- (void) zoomItemAction: (id) sender
{
  NSNumber* selectedFactorObject = [[sender selectedCell] representedObject];
  
  if (selectedFactorObject == nil)
  {
    NSLog(@"Scale popup action: setting arbitrary zoom factors is not yet supported.");
    return;
  }
  else
  {
    [self setScaleFactor: [selectedFactorObject floatValue] adjustPopup: NO];
  }
}
    
//--------------------------------------------------------------------------------------------------
    
- (void) setScaleFactor: (float) newScaleFactor adjustPopup: (BOOL) flag
{
  if (mScaleFactor != newScaleFactor)
  {
    mScaleFactor = newScaleFactor;
    if (flag)
    {
      unsigned count = 0;
      unsigned numberOfDefaultItems = sizeof(DefaultScaleMenuFactors) / sizeof(float);
      
      // We only work with some preset zoom values. If the given value does not correspond
      // to one then show no selection.
      while (count < numberOfDefaultItems && (fabs(newScaleFactor - DefaultScaleMenuFactors[count]) > 0.07))
        count++;
      if (count == numberOfDefaultItems)
        [mZoomPopup selectItemAtIndex: -1];
      else
      {
        [mZoomPopup selectItemAtIndex: count];
        
        // Set scale factor to found preset value if it comes close.
        mScaleFactor = DefaultScaleMenuFactors[count];
      }
    }
    else
    {
      // Internally set. Notify owner.
      [mCallback notify: IBNZoomChanged message: nil location: NSZeroPoint value: newScaleFactor];
    }    
  }
}

//--------------------------------------------------------------------------------------------------

/**
 * Called from the notification method to update the caret position display.
 */
- (void) setCaretPosition: (NSPoint) position
{
  // Make the position one-based.
  int newX = (int) position.x + 1;
  int newY = (int) position.y + 1;
  
  if (mCurrentCaretX != newX || mCurrentCaretY != newY)
  {
    mCurrentCaretX = newX;
    mCurrentCaretY = newY;
    
    [mCaretPositionLabel setStringValue: [NSString stringWithFormat: @"%d:%d", newX, newY]];
  }
}

//--------------------------------------------------------------------------------------------------

/**
 * Makes the bar resize to the smallest width that can accomodate the currently enabled items.
 */
- (void) sizeToFit
{
  NSRect frame = [self frame];
  frame.size.width = 0;
  if (mDisplayMask & IBShowZoom)
    frame.size.width += [mZoomPopup frame].size.width;
  
  if (mDisplayMask & IBShowCaretPosition)
    frame.size.width += [mCaretPositionLabel frame].size.width;
  
  if (mDisplayMask & IBShowStatusText)
    frame.size.width += [mStatusTextLabel frame].size.width;
  
  [self setFrame: frame];
}

@end
