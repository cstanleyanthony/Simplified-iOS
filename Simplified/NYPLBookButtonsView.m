//
//  NYPLBookButtonsView.m
//  Simplified
//
//  Created by Ben Anderman on 8/27/15.
//  Copyright (c) 2015 NYPL Labs. All rights reserved.
//

#import "NYPLBook.h"
#import "NYPLBookAcquisition.h"
#import "NYPLBookRegistry.h"
#import "NYPLBookButtonsView.h"
#import "NYPLRoundedButton.h"
#import "NYPLSettings.h"

@interface NYPLBookButtonsView ()

@property (nonatomic) UIActivityIndicatorView *activityIndicator;
@property (nonatomic) NYPLRoundedButton *deleteButton;
@property (nonatomic) NYPLRoundedButton *downloadButton;
@property (nonatomic) NYPLRoundedButton *readButton;
@property (nonatomic) NSArray *visibleButtons;
@property (nonatomic) id observer;

@end

@implementation NYPLBookButtonsView

- (instancetype)init
{
  self = [super init];
  if(!self) {
    return self;
  }
  
  self.deleteButton = [NYPLRoundedButton button];
  [self.deleteButton addTarget:self action:@selector(didSelectReturn) forControlEvents:UIControlEventTouchUpInside];
  [self addSubview:self.deleteButton];

  self.downloadButton = [NYPLRoundedButton button];
  [self.downloadButton addTarget:self action:@selector(didSelectDownload) forControlEvents:UIControlEventTouchUpInside];
  [self addSubview:self.downloadButton];

  self.readButton = [NYPLRoundedButton button];
  [self.readButton addTarget:self action:@selector(didSelectRead) forControlEvents:UIControlEventTouchUpInside];
  [self addSubview:self.readButton];
  
  self.activityIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
  self.activityIndicator.hidesWhenStopped = YES;
  [self addSubview:self.activityIndicator];
  
  self.observer = [[NSNotificationCenter defaultCenter]
   addObserverForName:NYPLBookProcessingDidChangeNotification
   object:nil
   queue:[NSOperationQueue mainQueue]
   usingBlock:^(NSNotification *note) {
     if([note.userInfo[@"identifier"] isEqualToString:self.book.identifier]) {
       [self updateProcessingState];
     }
   }];
  
  return self;
}

- (void)dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver:self.observer];
}

- (void)updateButtonFrames
{
  NYPLRoundedButton *lastButton = nil;
  for (NYPLRoundedButton *button in self.visibleButtons) {
    [button sizeToFit];
    CGRect frame = button.frame;
    if (!lastButton) {
      frame.origin = CGPointZero;
    } else {
      frame.origin = CGPointMake(CGRectGetMaxX(lastButton.frame) + 5,
                                 CGRectGetMinY(lastButton.frame));
    }
    lastButton = button;
    button.frame = frame;
  }
  self.activityIndicator.center = CGPointMake(CGRectGetMaxX(lastButton.frame) + 5 + self.activityIndicator.frame.size.width / 2,
                                              lastButton.center.y);
}

- (void)sizeToFit
{
  NYPLRoundedButton *lastButton = [self.visibleButtons lastObject];
  CGRect frame = self.frame;
  frame.size = CGSizeMake(CGRectGetMaxX(lastButton.frame), CGRectGetMaxY(lastButton.frame));
  self.frame = frame;
}

- (void)updateProcessingState
{
  BOOL state = [[NYPLBookRegistry sharedRegistry] processingForIdentifier:self.book.identifier];
  if(state) {
    [self.activityIndicator startAnimating];
  } else {
    [self.activityIndicator stopAnimating];
  }
  for(NYPLRoundedButton *button in @[self.downloadButton, self.deleteButton, self.readButton]) {
    button.enabled = !state;
  }
}

- (void)updateButtons
{
  NSArray *visibleButtonInfo = nil;
  static NSString *const ButtonKey = @"button";
  static NSString *const TitleKey = @"title";
  static NSString *const AddIndicatorKey = @"addIndicator";
  
  BOOL preloaded = [[[NYPLSettings sharedSettings] preloadedBookIdentifiers] containsObject:self.book.identifier];
  NSString *fulfillmentId = [[NYPLBookRegistry sharedRegistry] fulfillmentIdForIdentifier:self.book.identifier];
  
  switch(self.state) {
    case NYPLBookButtonsStateCanBorrow:
      visibleButtonInfo = @[@{ButtonKey: self.downloadButton, TitleKey: @"Borrow"}];
      break;
    case NYPLBookButtonsStateCanKeep:
      visibleButtonInfo = @[@{ButtonKey: self.downloadButton, TitleKey: @"Download"}];
      break;
    case NYPLBookButtonsStateCanHold:
      visibleButtonInfo = @[@{ButtonKey: self.downloadButton, TitleKey: @"Hold"}];
      break;
    case NYPLBookButtonsStateHolding:
      visibleButtonInfo = @[@{ButtonKey: self.deleteButton,   TitleKey: @"CancelHold", AddIndicatorKey: @(YES)}];
      break;
    case NYPLBookButtonsStateHoldingFOQ:
      visibleButtonInfo = @[@{ButtonKey: self.downloadButton, TitleKey: @"Borrow", AddIndicatorKey: @(YES)},
                            @{ButtonKey: self.deleteButton,   TitleKey: @"CancelHold"}];
      break;
    case NYPLBookButtonsStateDownloadNeeded:
    {
      NSString *title = (self.book.acquisition.openAccess || preloaded) ? @"Delete": @"ReturnNow";
      visibleButtonInfo = @[@{ButtonKey: self.downloadButton, TitleKey: @"Download", AddIndicatorKey: @(YES)},
                            @{ButtonKey: self.deleteButton,   TitleKey: title}];
      break;
    }
    case NYPLBookButtonsStateDownloadSuccessful:
      // Fallthrough
    case NYPLBookButtonsStateUsed:
    {
      NSString *title = (self.book.acquisition.openAccess || preloaded) ? @"Delete" : @"ReturnNow";
      visibleButtonInfo = @[@{ButtonKey: self.readButton,     TitleKey: @"Read", AddIndicatorKey: @(YES)},
                            @{ButtonKey: self.deleteButton,   TitleKey: title}];
      break;
    }
  }
  
  NSMutableArray *visibleButtons = [NSMutableArray array];
  
  BOOL fulfillmentIdRequired = NO;
  #if defined(FEATURE_DRM_CONNECTOR)
  
  // It's required unless the book is being held and has a revoke link
  fulfillmentIdRequired = !(self.state == NYPLBookButtonsStateHolding && self.book.acquisition.revoke);
  
  #endif
  
  for (NSDictionary *buttonInfo in visibleButtonInfo) {
    NYPLRoundedButton *button = buttonInfo[ButtonKey];
    if(button == self.deleteButton && !preloaded && (!fulfillmentId && fulfillmentIdRequired)) {
      if(!self.book.acquisition.openAccess) {
        continue;
      }
    }
    button.hidden = NO;
    [button setTitle:NSLocalizedString(buttonInfo[TitleKey], nil) forState:UIControlStateNormal];
    if ([buttonInfo[AddIndicatorKey] isEqualToValue:@(YES)]) {
      if (self.book.availableUntil && [self.book.availableUntil timeIntervalSinceNow] > 0) {
        button.type = NYPLRoundedButtonTypeClock;
        button.endDate = self.book.availableUntil;
      } else {
        button.type = NYPLRoundedButtonTypeNormal;
        // We could handle queue support here if we wanted it.
        // button.type = NYPLRoundedButtonTypeQueue;
        // button.queuePosition = self.book.holdPosition;
      }
    } else {
      button.type = NYPLRoundedButtonTypeNormal;
    }
    [visibleButtons addObject:button];
  }
  for (NYPLRoundedButton *button in @[self.downloadButton, self.deleteButton, self.readButton]) {
    if (![visibleButtons containsObject:button]) {
      button.hidden = YES;
    }
  }
  self.visibleButtons = visibleButtons;
  [self updateButtonFrames];
}

- (void)setBook:(NYPLBook *)book
{
  _book = book;
  [self updateButtons];
  [self updateProcessingState];
}

- (void)setState:(NYPLBookButtonsState const)state
{
  _state = state;
  [self updateButtons];
}

#pragma mark - Button actions

- (void)didSelectReturn
{
  [self.delegate didSelectReturnForBook:self.book];
}

- (void)didSelectRead
{
  [self.delegate didSelectReadForBook:self.book];
}

- (void)didSelectDownload
{
  [self.delegate didSelectDownloadForBook:self.book];
}

@end