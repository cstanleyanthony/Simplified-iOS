#import "NYPLBookCell.h"

@class NYPLBook;
@class NYPLBookNormalCell;

typedef NS_ENUM(NSInteger, NYPLBookNormalCellState) {
  NYPLBookNormalCellStateCanBorrow,
  NYPLBookNormalCellStateCanKeep,
  NYPLBookNormalCellStateDownloadNeeded,
  NYPLBookNormalCellStateDownloadSuccessful,
  NYPLBookNormalCellStateUsed
};

@protocol NYPLBookNormalCellDelegate

- (void)didSelectDeleteForBookNormalCell:(NYPLBookNormalCell *)cell;
- (void)didSelectDownloadForBookNormalCell:(NYPLBookNormalCell *)cell;
- (void)didSelectReadForBookNormalCell:(NYPLBookNormalCell *)cell;

@end

@interface NYPLBookNormalCell : NYPLBookCell

@property (nonatomic) NYPLBook *book;
@property (nonatomic, weak) id<NYPLBookNormalCellDelegate> delegate;
@property (nonatomic) NYPLBookNormalCellState state;

@end
