@import <Foundation/CPObject.j>
@import <Foundation/CPArray.j>
@import <AppKit/CPView.j>
@import <AppKit/CPTextField.j>
@import "EventModel.j"
@import "Utils.j"

@implementation TimetableView : CPView
{
	int _minHour, _maxHour;
	int _minDay, _maxDay;
	CPArray _labels;
	EventModel _model;
}

- (id)initWithFrame: (CGRect)aFrame
{
	self = [super initWithFrame: aFrame];
	if (self) {
		_minHour = 8;
		_maxHour = 18;
		_minDay = 0;
		_maxDay = 7;
		_labels = [[CPArray alloc] init];
		_model = [[EventModel alloc] initWithView: self];
		[self regenLabels];
	}
	return self
}

- (EventModel)model
{
	return _model;
}

- (CPRect)timeRectFrom: (float)startHour to: (float)endHour onDay: (int)day
{
	var gBounds = [self gridBounds];
	var gHeight = CPRectGetHeight(gBounds);
	var gWidth = CPRectGetWidth(gBounds);
	
	var yPerHour = Math.floor(gHeight / (_maxHour - _minHour));
	var xPerDay  = Math.floor(gWidth / (_maxDay - _minDay));
	
	return CPMakeRect(CPRectGetMinX(gBounds) + xPerDay * (day - _minDay),
					  CPRectGetMinY(gBounds) + yPerHour * (startHour - _minHour),
					  xPerDay, yPerHour * (endHour - startHour));
}

- (void)resizeSubviewsWithOldSize: (CGSize)aSize
{
	[super resizeSubviewsWithOldSize: aSize];
	[self regenLabels];
}

- (void)regenLabels
{
	var n = [_labels count];
	if (n > 0) {
		for (var i = 0; i < n; i++) {
			var v = [_labels objectAtIndex: i];
			[v removeFromSuperview];
		}
		[_labels removeAllObjects];
	}
	
	var gBounds = [self gridBounds];
	var gHeight = CPRectGetHeight(gBounds);
	var gWidth = CPRectGetWidth(gBounds);
	
	var yPerHour = gHeight / (_maxHour - _minHour);
	var xPerDay  = gWidth / (_maxDay - _minDay);
	
	for (var day=_minDay; day<=_maxDay; day++) {
		var baseX = CPRectGetMinX(gBounds) + xPerDay * (day - _minDay);
		var lBounds = CPMakeRect(baseX, CPRectGetMinY(gBounds)-20, xPerDay, 20);
		var label = [[CPTextField alloc] initWithFrame: lBounds];
		[label setStringValue: TimetableDays[day]];
		[self addSubview: label];
		[_labels addObject: label];
	}
	
	for (var hour=_minHour; hour<=_maxHour; hour++) {
		var baseY = CPRectGetMinY(gBounds) + yPerHour * (hour - _minHour);
		var lBounds = CPMakeRect(CPRectGetMinX(gBounds)-22, baseY-10,
		                         20, 20);
		var label = [[CPTextField alloc] initWithFrame: lBounds];
		[label setStringValue: hour];
		[self addSubview: label];
		[_labels addObject: label];
	}
}

- (CPRect)gridBounds
{
	var bounds = [self bounds];
	return CPMakeRect(CPRectGetMinX(bounds)+40, CPRectGetMinY(bounds)+40,
					  CPRectGetWidth(bounds)-60, CPRectGetHeight(bounds)-60);
}

- (void)drawRect: (CPRect)rect
{	
	var context = [[CPGraphicsContext currentContext] graphicsPort];
	
	var gBounds = [self gridBounds];
	var gHeight = CPRectGetHeight(gBounds);
	var gWidth = CPRectGetWidth(gBounds);
	
	var yPerHour = Math.floor(gHeight / (_maxHour - _minHour));
	var xPerDay  = Math.floor(gWidth / (_maxDay - _minDay));
	
	// sunday
	if (_minDay == 0) {
		var rect = CPMakeRect(CPRectGetMinX(gBounds), CPRectGetMinY(gBounds),
							  xPerDay, gHeight);
		CGContextSetFillColor(context, [CPColor colorWithHexString: "e7eef8"])
		CGContextFillRect(context, rect);
	}

	// saturday
	if (_maxDay == 7) {
		var baseX = CPRectGetMinX(gBounds) + xPerDay * (6 - _minDay);
		var rect = CPMakeRect(baseX, CPRectGetMinY(gBounds),
							  xPerDay, gHeight);
		CGContextSetFillColor(context, [CPColor colorWithHexString: "e7eef8"])
		CGContextFillRect(context, rect);
	}
	
	// draw minor grid
	CGContextBeginPath(context);
	for (var hour=_minHour; hour<_maxHour; hour++) {
		var baseY = CPRectGetMinY(gBounds) + yPerHour * (hour - _minHour + 0.5);
		CGContextMoveToPoint(context, CPRectGetMinX(gBounds), baseY + 0.5);
		CGContextAddLineToPoint(context, CPRectGetMaxX(gBounds), baseY + 0.5);
	}
	CGContextSetStrokeColor(context, [CPColor colorWithHexString: "e0e0e0"]);
	CGContextStrokePath(context);
	
	// draw major grid
	CGContextBeginPath(context);
	for (var hour=_minHour; hour<=_maxHour; hour++) {
		var baseY = CPRectGetMinY(gBounds) + yPerHour * (hour - _minHour);
		CGContextMoveToPoint(context, CPRectGetMinX(gBounds), baseY + 0.5);
		CGContextAddLineToPoint(context, CPRectGetMaxX(gBounds), baseY + 0.5);
	}
	for (var day=_minDay; day<=_maxDay; day++) {
		var baseX = CPRectGetMinX(gBounds) + xPerDay * (day - _minDay);
		CGContextMoveToPoint(context, baseX + 0.5, CPRectGetMinY(gBounds));
		CGContextAddLineToPoint(context, baseX + 0.5, CPRectGetMaxY(gBounds));
	}
	CGContextSetStrokeColor(context, [CPColor colorWithHexString: "b5b5b5"]);
	CGContextStrokePath(context);
}

@end