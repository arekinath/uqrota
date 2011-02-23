/*
 * AppController.j
 * webui
 *
 * Created by You on February 12, 2011.
 * Copyright 2011, Your Company All rights reserved.
 */

@import <Foundation/CPObject.j>
@import "TimetableView.j"
@import "EventModel.j"
@import "CourseModel.j"


@implementation AppController : CPObject
{
  CPWindow window;
  id contentView;
  
  id timetableView;
}

- (void)applicationDidFinishLaunching:(CPNotification)aNotification
{
  window = [[CPWindow alloc] initWithContentRect:CGRectMakeZero() styleMask:CPBorderlessBridgeWindowMask];
  
  contentView = [window contentView];

	var bounds = [contentView bounds];
  timetableView = [[TimetableView alloc] initWithFrame: bounds];

  //[ttv sizeToFit];
  [timetableView setAutoresizingMask: CPViewWidthSizable | CPViewHeightSizable];
  [timetableView setCenter:[contentView center]];

  [contentView addSubview: timetableView];

  [window orderFront: self];

  [self fetchCourseWithCode: "CSSE1001"];

  // Uncomment the following line to turn on the standard menu bar.
  //CPMenu setMenuBarVisible:YES];
}

- (void)fetchCourseWithCode: (CPString)code
{
  if ([Course isCached: code]) {
    [self courseDidLoad: [Course fromCache: code]];
  } else {
    var course = [[Course alloc] initWithCode: code andDelegate: self];
  }
}

- (void)courseDidLoad: (id)aCourse
{
  var oid = [aCourse data].offerings[0].id;
  if ([Offering isCached: oid]) {
    [self offeringDidLoad: [Offering fromCache: oid]];
  } else {
    var offer = [[Offering alloc] initWithId: oid andDelegate: self];
  }
}

- (void)offeringDidLoad: (id)anOffering
{
  var data = [anOffering data];
  var m = [timetableView model];
  
  for (var i=0; i < data.series.length; i++) {
    var series = data.series[i];
    var sessions = series.groups[0].sessions;
    for (var j=0; j< sessions.length; j++) {
      var s = [[Session alloc] initWithObject: sessions[j]];
      [m addSession: s];
    }
  }
  
}

@end
