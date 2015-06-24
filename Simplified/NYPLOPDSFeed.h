@class NYPLXML;

typedef NS_ENUM(NSInteger, NYPLOPDSFeedType) {
  NYPLOPDSFeedTypeInvalid,
  NYPLOPDSFeedTypeEmpty,
  NYPLOPDSFeedTypeAcquisitionGrouped,
  NYPLOPDSFeedTypeAcquisitionUngrouped,
  NYPLOPDSFeedTypeNavigation
};

@interface NYPLOPDSFeed : NSObject

@property (nonatomic, readonly) NSArray *entries;
@property (nonatomic, readonly) NSString *identifier;
@property (nonatomic, readonly) NSArray *links;
@property (nonatomic, readonly) NSString *title;
@property (nonatomic, readonly) NYPLOPDSFeedType type;
@property (nonatomic, readonly) NSDate *updated;

+ (id)new NS_UNAVAILABLE;
- (id)init NS_UNAVAILABLE;

+ (void)withURL:(NSURL *)URL completionHandler:(void (^)(NYPLOPDSFeed *feed))handler;

// designated initializer
- (instancetype)initWithXML:(NYPLXML *)feedXML;

@end
