/*
 * AppController.j
 * webui
 *
 * Created by You on February 12, 2011.
 * Copyright 2011, Your Company All rights reserved.
 */

@import <Foundation/CPObject.j>
@import "TimetableView.j"


@implementation AppController : CPObject
{
}

- (void)applicationDidFinishLaunching:(CPNotification)aNotification
{
    var theWindow = [[CPWindow alloc] initWithContentRect:CGRectMakeZero() styleMask:CPBorderlessBridgeWindowMask],
        contentView = [theWindow contentView];

	var bounds = [contentView bounds];
    var ttv = [[TimetableView alloc] initWithFrame: bounds];

    //[ttv sizeToFit];
    [ttv setAutoresizingMask: CPViewWidthSizable | CPViewHeightSizable];
    [ttv setCenter:[contentView center]];

    [contentView addSubview: ttv];

    [theWindow orderFront: self];

    // Uncomment the following line to turn on the standard menu bar.
    //CPMenu setMenuBarVisible:YES];
}

@end
