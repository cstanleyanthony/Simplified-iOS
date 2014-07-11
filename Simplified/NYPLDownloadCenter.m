#import "NYPLBook.h"
#import "NYPLMyBooksRegistry.h"

#import "NYPLDownloadCenter.h"

@implementation NYPLDownloadCenter

+ (NYPLDownloadCenter *)sharedDownloadCenter
{
  static dispatch_once_t predicate;
  static NYPLDownloadCenter *sharedDownloadCenter = nil;
  
  dispatch_once(&predicate, ^{
    sharedDownloadCenter = [[self alloc] init];
    if(!sharedDownloadCenter) {
      NYPLLOG(@"Failed to create shared download center.");
    }
  });
  
  return sharedDownloadCenter;
}

- (void)startDownloadForBook:(NYPLBook *const)book
{
  [[NYPLMyBooksRegistry sharedRegistry] addBook:[book bookWithState:NYPLBookStateDownloading]];
}

@end
