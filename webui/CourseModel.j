@import <Foundation/CPArray.j>
@import <Foundation/CPObject.j>
@import <Foundation/CPString.j>
@import <Foundation/CPDictionary.j>
@import <Foundation/CPURLRequest.j>
@import <Foundation/CPURLConnection.j>
@import "Utils.j"

var OfferingCache = [[CPDictionary alloc] init];

@implementation Offering : CPObject
{
  CPString _id;
  id _json;
  
  CPURLConnection _connection;
  id _delegate;
}

+ (bool)isCached: (CPString)anId
{
  return [OfferingCache containsKey: anId];
}

+ (id)fromCache: (CPString)anId
{
  return [OfferingCache valueForKey: anId];
}

- (id)initWithId: (CPString)anId
{
  self = [super init];
  if (self) {
    _id = anId;
  }
  return self;
}

- (id)initWithId: (CPString)anId andDelegate: (id)aDelegate
{
  self = [super init];
  if (self) {
    _id = anId;
    [self refreshWithDelegate: aDelegate];
  }
  return self;
}

- (void)refreshWithDelegate: (id)aDelegate
{
  _delegate = aDelegate;
  var request = [CPURLRequest requestWithURL: RotaBase+"/offering/"+_id+".json"];
  [request setHTTPMethod: "GET"];
  _connection = [CPURLConnection connectionWithRequest: request delegate: self];
}

- (void)connection: (CPURLConnection)connection didReceiveData:(CPString)data
{
  _json = [data objectFromJSON];
  // set up back links
  for (var i=0; i < _json.series.length; i++) {
    var ser = _json.series[i];
    ser.offering = _json;
    for (var j=0; j < ser.groups.length; j++) {
      var group = ser.groups[j];
      group.series = ser;
      for (var k=0; k < group.sessions.length; k++) {
        var sess = group.sessions[k];
        sess.group = group;
      }
    }
  }
  [CourseCache setValue: self forKey: _id];
  [_delegate offeringDidLoad: self];
}

- (void)connection: (CPURLConnection)connection didFailWithError:(CPError)anError
{
  alert("Error fetching offering #" + _id);
}

- (CPString)code
{
  return _code;
}

- (id)data
{
  return _json;
}

@end


var CourseCache = [[CPDictionary alloc] init];

@implementation Course : CPObject
{
  CPString _code;
  id _json;
  
  CPURLConnection _connection;
  id _delegate;
}

+ (bool)isCached: (CPString)aCode
{
  return [CourseCache containsKey: aCode];
}

+ (id)fromCache: (CPString)aCode
{
  return [CourseCache valueForKey: aCode];
}

- (id)initWithCode: (CPString)aCode
{
  self = [super init];
  if (self) {
    _code = aCode;
  }
  return self;
}

- (id)initWithCode: (CPString)aCode andDelegate: (id)aDelegate
{
  self = [super init];
  if (self) {
    _code = aCode;
    [self refreshWithDelegate: aDelegate];
  }
  return self;
}

- (void)refreshWithDelegate: (id)aDelegate
{
  _delegate = aDelegate;
  var request = [CPURLRequest requestWithURL: RotaBase+"/course/"+_code+".json"];
  [request setHTTPMethod: @"GET"];
  _connection = [CPURLConnection connectionWithRequest: request delegate: self];
}

- (void)connection: (CPURLConnection)connection didReceiveData:(CPString)data
{
  _json = [data objectFromJSON];
  // set up backlinks
  for (var i=0; i < _json.offerings.length; i++) {
    var off = _json.offerings[i];
    off.course = _json;
  }
  [CourseCache setValue: self forKey: _code];
  [_delegate courseDidLoad: self];
}

- (void)connection: (CPURLConnection)connection didFailWithError:(CPError)anError
{
  alert("Error fetching course: " + _code);
}

- (CPString)code
{
  return _code;
}

- (id)data
{
  return _json;
}

@end
