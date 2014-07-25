#import "NYPLBook.h"

static NSString *const NYPLMyBooksDownloadCenterDidChange =
  @"NYPLMyBooksDownloadCenterDidChange";

@interface NYPLMyBooksDownloadCenter : NSObject

+ (NYPLMyBooksDownloadCenter *)sharedDownloadCenter;

// This method should be called iff a barcode and PIN are already set. If they're not, the part of
// the app that wants to initiate a download is responsible for collecting that information first.
// If it fails to do so and just starts the download anyway, the user will get a download error and
// have to resume the download through My Books (which is less than ideal). The rationale for doing
// it this way is that NYPLMyBooksDownloadCenter is not able to cleanly present a modal view
// controller itself in order to obtain the credentials from the user.
- (void)startDownloadForBook:(NYPLBook *)book;

- (void)cancelDownloadForBookIdentifier:(NSString *)identifier;

// The value returned is in the range [0.0, 1.0]. Once a download for a particular book has begun,
// its progress will be kept in memory for the remainder of the application run and may be retrieved
// at any time.
- (double)downloadProgressForBookIdentifier:(NSString *)bookIdentifier;

@end
