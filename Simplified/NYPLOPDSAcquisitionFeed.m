#import "NSDate+NYPLDateAdditions.h"
#import "NYPLOPDSEntry.h"
#import "SMXMLElement+NYPLElementAdditions.h"

#import "NYPLOPDSAcquisitionFeed.h"

@interface NYPLOPDSAcquisitionFeed ()

@property (nonatomic) NSArray *entries;
@property (nonatomic) NSString *identifier;
@property (nonatomic) NSString *title;
@property (nonatomic) NSDate *updated;

@end

@implementation NYPLOPDSAcquisitionFeed

- (id)initWithDocument:(SMXMLDocument *)document
{
  self = [super init];
  if(!self) return nil;
  
  if(!((self.identifier = [document.root childNamed:@"id"].valueString))) {
    NSLog(@"NYPLOPDSAcquisitionFeed: Missing required 'id' element.");
    return nil;
  }
  
  if(!((self.title = [document.root childNamed:@"title"].valueString))) {
    NSLog(@"NYPLOPDSAcquisitionFeed: Missing required 'title' element.");
    return nil;
  }
  
  {
    NSString *const updatedString = [document.root childNamed:@"updated"].valueString;
    if(!updatedString) {
      NSLog(@"NYPLOPDSAcquisitionFeed: Missing required 'updated' element.");
      return nil;
    }
    
    self.updated = [NSDate dateWithRFC3339:updatedString];
    if(!self.updated) {
      NSLog(@"NYPLOPDSAcquisitionFeed: Element 'updated' does not contain an RFC 3339 date.");
      return nil;
    }
  }
  
  {
    NSMutableArray *const entries = [NSMutableArray array];
    
    for(SMXMLElement *const entryElement in [document.root childrenNamed:@"entry"]) {
      NYPLOPDSEntry *const entry = [[NYPLOPDSEntry alloc] initWithElement:entryElement];
      if(!entry) {
        NSLog(@"NYPLOPDSAcquisitionFeed: Ingoring malformed 'entry' element.");
        continue;
      }
      [entries addObject:entry];
    }
    
    self.entries = entries;
  }
  
  return self;
}

@end
