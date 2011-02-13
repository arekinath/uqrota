@import <Foundation/CPArray.j>
@import <Foundation/CPObject.j>
@import <AppKit/CPView.j>
@import <AppKit/CPTextField.j>
@import <Foundation/CPDictionary.j>
@import "Utils.j"

@implementation Session : CPView
{
	int _id;
	float _start, _end;
	int _day;
	
	int _tidx;
	int _tshare;
	
	id _xml;
	id _model;
	
	CPTextField _label;
}

- (id)initWithXml: (id)object
{
	self = [super init];
	if (self) {
		_xml = object;
		_start = object.startmins / 60.0;
		_end = object.finishmins / 60.0;
		_day = DayNumberOf(object.day);
		_label = [[CPTextField alloc] init];
		[_label setStringValue: "Session"];
		[self addSubview: _label];
	}
	return self;
}

- (id)model
{
	return _model;
}

- (void)setModel: (id)aModel
{
	_model = aModel;
}

- (void)updateUsage
{
	_tidx = [_model incrementUsageFrom: _start to: _end onDay: _day];
}

- (void)updateFrame
{
	_tshare = [_model maxUsageFrom: _start to: _end onDay: _day];
	[self resizeWithOldSuperviewSize: nil];
}

- (void)resizeWithOldSuperviewSize: (CGSize)oldSize
{
	var totalRect = [[self superview] timeRectFrom: _start to: _end onDay: _day];
	var w = CPRectGetWidth(totalRect) / _tshare;
	var x = CPRectGetMinX(totalRect) + w * _tidx;
	var myRect = CPMakeRect(x, CPRectGetMinY(totalRect), w, CPRectGetHeight(totalRect));
	[self setFrame: myRect];
	[_label setFrame: CPRectInset([self bounds], 5, 5)];
}

- (void)drawRect: (CPRect)aRect
{
	var context = [[CPGraphicsContext currentContext] graphicsPort];
	var bounds = [self bounds];
	
	CGContextSetFillColor(context, [CPColor colorWithHexString: "f0e0ff"]);
	CGContextSetStrokeColor(context, [CPColor colorWithHexString: "303030"]);
	CGContextSetLineWidth(context, 2.0);
	CGContextSetAlpha(context, 0.8);
	
	CGContextFillRoundedRectangleInRect(context, bounds, 7, YES, YES, YES, YES);
	CGContextStrokeRoundedRectangleInRect(context, bounds, 7, YES, YES, YES, YES);
}

@end



@implementation EventModel : CPObject
{
	CPDictionary _timeUsage;
	CPArray _sessions;
	id _view;
}

- (id)initWithView: (id)aView
{
	self = [super init];
	if (self) {
		_sessions = [[CPArray alloc] init];
		_timeUsage = [[CPDictionary alloc] init];
		_view = aView;
	}
	return self;
}

- (void)addSession: (id)aSession
{
	[_sessions addObject: aSession];
	[aSession setModel: self];
	[_view addSubview: aSession];
	[self updateUsage];
}

- (void)updateUsage
{
	[self resetUsage];
	for (var i=0; i<[_sessions count]; i++) {
		var v = [_sessions objectAtIndex: i];
		[v updateUsage];
	}
	
	for (var i=0; i<[_sessions count]; i++) {
		var v = [_sessions objectAtIndex: i];
		[v updateFrame];
	}
}

- (void)resetUsage
{
	[_timeUsage removeAllObjects];
}

- (int)maxUsageFrom: (float)startHour to: (float)endHour onDay: (int)day
{
	var startIncr = 0.25 * Math.floor(startHour / 0.25);
	var endIncr = 0.25 * Math.ceil(endHour / 0.25);
	var maxUsage = 0;
	
	for (var th = startIncr; th != endIncr; th += 0.25) {
		var k = day + "|" + th;
		if ([_timeUsage containsKey: k]) {
			var v = [_timeUsage valueForKey: k];
			if (v > maxUsage)
				maxUsage = v;
		}
	}
	
	return maxUsage;
}

- (int)incrementUsageFrom: (float)startHour to: (float)endHour onDay: (int)day
{
	var startIncr = 0.25 * Math.floor(startHour / 0.25);
	var endIncr = 0.25 * Math.ceil(endHour / 0.25);
	var maxUsage = 0;
	
	for (var th = startIncr; th != endIncr; th += 0.25) {
		var k = day + "|" + th;
		if ([_timeUsage containsKey: k]) {
			var v = [_timeUsage valueForKey: k];
			if (v > maxUsage)
				maxUsage = v;
			v += 1;
			[_timeUsage setValue: v forKey: k];
		} else {
			[_timeUsage setValue: 1 forKey: k];
		}
	}
	
	return maxUsage;
}

- (int)decrementUsageFrom: (float)startHour to: (float)endHour onDay: (int)day
{
	var startIncr = 0.25 * Math.floor(startHour / 0.25);
	var endIncr = 0.25 * Math.ceil(endHour / 0.25);
	var maxUsage = 0;
	
	for (var th = startIncr; th != endIncr; th += 0.25) {
		var k = day + "|" + th;
		if ([_timeUsage containsKey: k]) {
			var v = [_timeUsage valueForKey: k];
			if (v > maxUsage)
				maxUsage = v;
			v -= 1;
			[_timeUsage setValue: v forKey: k];
		} else {
			[_timeUsage setValue: 0 forKey: k];
		}
	}
	
	return maxUsage - 1;
}

@end