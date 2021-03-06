@import LocalAuthentication;
@import NYPLCardCreator;

#import "Bugsnag.h"
#import "NYPLAccount.h"
#import "NYPLAlertController.h"
#import "NYPLBasicAuth.h"
#import "NYPLBookCoverRegistry.h"
#import "NYPLBookRegistry.h"
#import "NYPLCatalogNavigationController.h"
#import "NYPLConfiguration.h"
#import "NYPLLinearView.h"
#import "NYPLMyBooksDownloadCenter.h"
#import "NYPLReachability.h"
#import "NYPLSettings.h"
#import "NYPLSettingsAccountDetailViewController.h"
#import "NYPLSettingsEULAViewController.h"
#import "NYPLRootTabBarController.h"
#import "UIFont+NYPLSystemFontOverride.h"
#import "UIView+NYPLViewAdditions.h"
#import "SimplyE-Swift.h"
#import <PureLayout/PureLayout.h>
#import <HelpStack/HSUtility.h>
#import "HSHelpStack.h"
#import "HSDeskGear.h"

#import "NYPLXML.h"
#import "NYPLOPDS.h"


@import CoreLocation;
@import MessageUI;

#if defined(FEATURE_DRM_CONNECTOR)
#import <ADEPT/ADEPT.h>
#endif

typedef NS_ENUM(NSInteger, CellKind) {
  CellKindAgeCheck,
  CellKindBarcodeImage,
  CellKindBarcode,
  CellKindPIN,
  CellKindLogInSignOut,
  CellKindRegistration,
  CellKindSyncButton,
  CellKindAbout,
  CellKindPrivacyPolicy,
  CellKindContentLicense,
  CellReportIssue,
  CellSupportCenter
};

@interface NYPLSettingsAccountDetailViewController () <NSURLSessionDelegate, UITextFieldDelegate, UIAlertViewDelegate>

@property (nonatomic) BOOL isLoggingInAfterSignUp;
@property (nonatomic) UITextField *barcodeTextField;
@property (nonatomic) UILabel *barcodeLabelImage;
@property (nonatomic) UILabel *barcodeLabelImageZoom;
@property (nonatomic) UIView *zoomView;
@property (nonatomic, copy) void (^completionHandler)();
@property (nonatomic) BOOL hiddenPIN;
@property (nonatomic) UITextField *PINTextField;
@property (nonatomic) NSURLSession *session;
@property (nonatomic) UIButton *PINShowHideButton;
@property (nonatomic) UIButton *barcodeScanButton;
@property (nonatomic) NSInteger accountType;
@property (nonatomic) Account *account;

@property (nonatomic) UITableViewCell *registrationCell;
@property (nonatomic) UITableViewCell *logInSignOutCell;
@property (nonatomic) UITableViewCell *ageCheckCell;

@property (nonatomic) NSMutableArray *tableData;
@property (nonatomic) bool rotated;

@property (nonatomic) UISwitch* switchView;

@end


@implementation NYPLSettingsAccountDetailViewController

NSInteger const linearViewTag = 1;
CGFloat const verticalMarginPadding = 2.0;

#pragma mark NSObject

- (instancetype)initWithAccount:(NSInteger)account
{
  self.accountType = account;
  self.account = [[AccountsManager sharedInstance] account:self.accountType];
  return [self init];
}

- (instancetype)init
{
  self = [super initWithStyle:UITableViewStyleGrouped];
  if(!self) return nil;
  
  self.title = NSLocalizedString(@"Account", nil);

  [[NSNotificationCenter defaultCenter]
   addObserver:self
   selector:@selector(accountDidChange)
   name:NYPLAccountDidChangeNotification
   object:nil];
  
  [[NSNotificationCenter defaultCenter]
   addObserver:self
   selector:@selector(keyboardDidShow:)
   name:UIKeyboardWillShowNotification
   object:nil];
  
  [[NSNotificationCenter defaultCenter]
   addObserver:self
   selector:@selector(keyboardWillHide)
   name:UIKeyboardWillHideNotification
   object:nil];
  
  [[NSNotificationCenter defaultCenter]
   addObserver:self
   selector:@selector(willResignActive)
   name:UIApplicationWillResignActiveNotification
   object:nil];

  [[NSNotificationCenter defaultCenter]
   addObserver:self
   selector:@selector(willEnterForeground)
   name:UIApplicationWillEnterForegroundNotification
   object:nil];
  
  NSURLSessionConfiguration *const configuration =
    [NSURLSessionConfiguration ephemeralSessionConfiguration];
  
  configuration.timeoutIntervalForResource = 20.0;
  
  self.session = [NSURLSession
                  sessionWithConfiguration:configuration
                  delegate:self
                  delegateQueue:[NSOperationQueue mainQueue]];
  
  return self;
}

- (void)dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark UIViewController

- (void)viewDidLoad
{
  [super viewDidLoad];
  
  self.view.backgroundColor = [NYPLConfiguration backgroundColor];
  
  self.barcodeTextField = [[UITextField alloc] initWithFrame:CGRectZero];
  self.barcodeTextField.delegate = self;
  self.barcodeTextField.placeholder = NSLocalizedString(@"BarcodeOrUsername", nil);
  self.barcodeTextField.keyboardType = UIKeyboardTypeASCIICapable;
  self.barcodeTextField.autocapitalizationType = UITextAutocapitalizationTypeNone;
  self.barcodeTextField.autocorrectionType = UITextAutocorrectionTypeNo;
  [self.barcodeTextField
   addTarget:self
   action:@selector(textFieldsDidChange)
   forControlEvents:UIControlEventEditingChanged];
  
  self.PINTextField = [[UITextField alloc] initWithFrame:CGRectZero];
  self.PINTextField.placeholder = NSLocalizedString(@"PIN", nil);
  self.PINTextField.keyboardType = UIKeyboardTypeNumberPad;
  self.PINTextField.secureTextEntry = YES;
  self.PINTextField.delegate = self;
  [self.PINTextField
   addTarget:self
   action:@selector(textFieldsDidChange)
   forControlEvents:UIControlEventEditingChanged];

  self.PINShowHideButton = [UIButton buttonWithType:UIButtonTypeSystem];
  [self.PINShowHideButton setTitle:NSLocalizedString(@"Show", nil) forState:UIControlStateNormal];
  [self.PINShowHideButton sizeToFit];
  [self.PINShowHideButton addTarget:self action:@selector(PINShowHideSelected)
                   forControlEvents:UIControlEventTouchUpInside];
  
  if (self.account.supportsBarcodeScanner) {
    self.barcodeScanButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.barcodeScanButton setImage:[UIImage imageNamed:@"ic_camera"] forState:UIControlStateNormal];
    [self.barcodeScanButton sizeToFit];
    [self.barcodeScanButton addTarget:self action:@selector(scanLibraryCard)
                   forControlEvents:UIControlEventTouchUpInside];

    self.barcodeTextField.rightView = self.barcodeScanButton;
    self.barcodeTextField.rightViewMode = UITextFieldViewModeAlways;
  }
  self.PINTextField.rightView = self.PINShowHideButton;
  self.PINTextField.rightViewMode = UITextFieldViewModeAlways;
  
  [self setupTableData];
  
  [self checkSyncSetting];
  self.switchView = [[UISwitch alloc] initWithFrame:CGRectZero];
}

- (void)barcodeZoom
{

  if (self.rotated)
  {
    self.rotated = NO;
       
    [self.barcodeLabelImageZoom removeFromSuperview];
    [self.zoomView removeFromSuperview];
  }
  else
  {
    self.rotated = YES;
    
    self.barcodeLabelImageZoom = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, self.view.frame.size.height  -130, self.view.frame.size.width/2)];
    
    CGAffineTransform transform = CGAffineTransformMakeRotation(-M_PI / 2);
    transform = CGAffineTransformScale(transform, 1.0, 3.0);
    [self.barcodeLabelImageZoom setTransform:transform];
    CGRect frame = self.barcodeLabelImageZoom.frame;
    frame.origin.x = 25 ;//+ (self.barcodeLabelImageZoom.frame.size.width/4);
    frame.origin.y = 10;
    self.barcodeLabelImageZoom.frame = frame;
    self.barcodeLabelImageZoom.text = [NSString stringWithFormat:@"A%@B", [NYPLAccount sharedAccount:self.accountType].authorizationIdentifier];
    self.barcodeLabelImageZoom.font = [UIFont fontWithName:@"CodabarLarge" size:50.0];
    self.barcodeLabelImageZoom.textAlignment = NSTextAlignmentCenter;
    self.barcodeLabelImageZoom.adjustsFontSizeToFitWidth = YES;
    self.barcodeLabelImageZoom.backgroundColor = [UIColor whiteColor];
    
    self.zoomView = [[UIView alloc] initWithFrame:self.tableView.frame];
    self.zoomView.backgroundColor = [UIColor whiteColor];
    
    [self.zoomView addSubview:self.barcodeLabelImageZoom];
    [self.view addSubview:self.zoomView];

    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(barcodeZoom)];
    [self.barcodeLabelImageZoom addGestureRecognizer:tap];
    self.barcodeLabelImageZoom.userInteractionEnabled = YES;

  }
}
- (void)setupTableData
{
  NSMutableArray *section0;
  if (self.account.needsAuth == NO) {
    section0 = @[@(CellKindAgeCheck)].mutableCopy;
  } else {
    section0 = @[@(CellKindBarcode),
                 @(CellKindPIN),
                 @(CellKindLogInSignOut)].mutableCopy;
  }
  
  NSMutableArray *sectionRegister = @[@(CellKindRegistration)].mutableCopy;

  if (self.account.needsAuth == YES && [[NYPLAccount sharedAccount:self.accountType] hasBarcodeAndPIN] && self.account.supportsBarcodeDisplay){
    [section0 insertObject:@(CellKindBarcodeImage) atIndex: 0];
  }
  NSMutableArray *section1 = [[NSMutableArray alloc] init];
  if (self.account.supportsSimplyESync && [self syncButtonShouldBeVisible]) {
    [section1 addObject:@(CellKindSyncButton)];
  }
  NSMutableArray *section2 = [[NSMutableArray alloc] init];
  if ([self.account getLicenseURL:URLTypePrivacyPolicy]) {
    [section2 addObject:@(CellKindPrivacyPolicy)];
  }
  if ([self.account getLicenseURL:URLTypeContentLicenses]) {
    [section2 addObject:@(CellKindContentLicense)];
  }
  
  if ([self registrationIsPossible]) {
    self.tableData = @[section0, sectionRegister, section1].mutableCopy;
  }
  else{
    self.tableData = @[section0, section1].mutableCopy;
  }
  

  NSMutableArray *supportCenter = [[NSMutableArray alloc] init];
  if (self.account.supportsHelpCenter)
  {
    [supportCenter addObject:@(CellSupportCenter)];
    [self.tableData addObject:supportCenter];
    
  }
  NSMutableArray *reportIssue = [[NSMutableArray alloc] init];
  if (self.account.supportEmail != nil)
  {
    [reportIssue addObject:@(CellReportIssue)];
    [self.tableData addObject:reportIssue];
  }
  [self.tableData addObject:section2];

  
  NSMutableArray *newArray = [[NSMutableArray alloc] init];
  for (NSMutableArray *section in self.tableData) {
    if ([section count] != 0) { [newArray addObject:section]; }
  }
  self.tableData = newArray;
}

- (void)viewWillAppear:(BOOL)animated
{
  [super viewWillAppear:animated];
  

  // The new credentials are not yet saved when logging in after signup. As such,
  // reloading the table would lose the values in the barcode and PIN fields.
  if(!self.isLoggingInAfterSignUp) {
    self.hiddenPIN = YES;
    [self accountDidChange];
    [self.tableView reloadData];
    [self updateShowHidePINState];
  }
}

#pragma mark - Account SignIn/SignOut

- (void)logIn
{
  assert(self.barcodeTextField.text.length > 0);
  assert(self.PINTextField.text.length > 0);
  
  [self.barcodeTextField resignFirstResponder];
  [self.PINTextField resignFirstResponder];
  
  [self setActivityTitleWithText:NSLocalizedString(@"Verifying", nil)];
  
  [[UIApplication sharedApplication] beginIgnoringInteractionEvents];
  
  [self validateCredentials];
}

- (void)logOut
{
  
#if defined(FEATURE_DRM_CONNECTOR)
  
  if([NYPLADEPT sharedInstance].workflowsInProgress) {
    [self presentViewController:[NYPLAlertController
                                 alertWithTitle:@"SettingsAccountViewControllerCannotLogOutTitle"
                                 message:@"SettingsAccountViewControllerCannotLogOutMessage"]
                       animated:YES
                     completion:nil];
    return;
  }
  
  [self setActivityTitleWithText:NSLocalizedString(@"SigningOut", nil)];
  [[UIApplication sharedApplication] beginIgnoringInteractionEvents];
  
  
  // Get a fresh licensor token before attempting to deauthorize
  Account *account = [[AccountsManager sharedInstance] account:self.accountType];
  NSMutableURLRequest *const request =
  [NSMutableURLRequest requestWithURL:[[NSURL URLWithString:[account catalogUrl]] URLByAppendingPathComponent:@"loans"]];
  
  request.timeoutInterval = 20.0;
  
  NSURLSessionDataTask *const task =
  [self.session
   dataTaskWithRequest:request
   completionHandler:^(NSData *data,
                       NSURLResponse *const response,
                       __unused NSError *const error) {
     
     NSInteger statusCode = ((NSHTTPURLResponse *) response).statusCode;
     if(statusCode == 200) {
       
       NYPLXML *loansXML = [NYPLXML XMLWithData:data];
       NYPLOPDSFeed *loansFeed = [[NYPLOPDSFeed alloc] initWithXML:loansXML];
       [[NYPLAccount sharedAccount:self.accountType] setLicensor:loansFeed.licensor];
       NYPLLOG_F(@"\nLicensor Token Updated: %@\nFor account: %@",loansFeed.licensor[@"clientToken"],[NYPLAccount sharedAccount:self.accountType].userID);
       
       [self deauthorizeDevice];

     } else {
       [self showLogoutAlertWithError:error responseCode:statusCode];
       [self removeActivityTitle];
       [[UIApplication sharedApplication] endIgnoringInteractionEvents];
     }
   }];

  [task resume];
  
#else
  
  [[NYPLMyBooksDownloadCenter sharedDownloadCenter] reset:self.accountType];
  [[NYPLBookRegistry sharedRegistry] reset:self.accountType];
  [[NYPLAccount sharedAccount:self.accountType] removeAll];
  [self setupTableData];
  [self.tableView reloadData];
  [self removeActivityTitle];
  [[UIApplication sharedApplication] endIgnoringInteractionEvents];

#endif
  
}

- (void)deauthorizeDevice
{

#if defined(FEATURE_DRM_CONNECTOR)

  void (^afterDeauthorization)() = ^() {
    [self removeActivityTitle];
    [[UIApplication sharedApplication] endIgnoringInteractionEvents];
    
    [[NYPLMyBooksDownloadCenter sharedDownloadCenter] reset:self.accountType];
    [[NYPLBookRegistry sharedRegistry] reset:self.accountType];
    
    [[NYPLAccount sharedAccount:self.accountType] removeAll];
    [self setupTableData];
    [self.tableView reloadData];
  };

  NSDictionary *licensor = [[NYPLAccount sharedAccount:self.accountType] licensor];
  if (!licensor) {
    NYPLLOG(@"No Licensor available to deauthorize device. Signing out NYPLAccount creds anyway.");
    [self bugsnagLogInvalidLicensor];
    afterDeauthorization();
    return;
  }

  NSMutableArray *licensorItems = [[licensor[@"clientToken"] stringByReplacingOccurrencesOfString:@"\n" withString:@""] componentsSeparatedByString:@"|"].mutableCopy;
  NSString *tokenPassword = [licensorItems lastObject];
  [licensorItems removeLastObject];
  NSString *tokenUsername = [licensorItems componentsJoinedByString:@"|"];
  
  NYPLLOG(@"***DRM Deactivation Attempt***");
  NYPLLOG_F(@"\nLicensor: %@\n",licensor);
  NYPLLOG_F(@"Token Username: %@\n",tokenUsername);
  NYPLLOG_F(@"Token Password: %@\n",tokenPassword);
  NYPLLOG_F(@"UserID: %@\n",[[NYPLAccount sharedAccount:self.accountType] userID]);
  NYPLLOG_F(@"DeviceID: %@\n",[[NYPLAccount sharedAccount:self.accountType] deviceID]);
  
  [[NYPLADEPT sharedInstance]
   deauthorizeWithUsername:tokenUsername
   password:tokenPassword
   userID:[[NYPLAccount sharedAccount:self.accountType] userID]
   deviceID:[[NYPLAccount sharedAccount:self.accountType] deviceID]
   completion:^(BOOL success, __unused NSError *error) {
     
     if(!success) {
       // Even though we failed, let the user continue to log out.
       // The most likely reason is a user changing their PIN.
       // TODO: Remote logging can be removed when it is determined that sufficient data has been collected.
       NYPLLOG(@"Failed to deauthorize successfully. User will lose an activation on this device.");
       [Bugsnag notifyError:[NSError errorWithDomain:@"org.nypl.labs.SimplyE" code:4 userInfo:nil]
                      block:^(BugsnagCrashReport * _Nonnull report) {
                        report.context = @"NYPLSettingsAccountDetailViewController";
                        report.severity = BSGSeverityInfo;
                        report.errorMessage = @"User has lost an activation on signout due to NYPLAdept Error.";
                      }];
     }
     else {
       NYPLLOG(@"***Successful DRM Deactivation***");
       // DELETE deviceID to adobeDevicesLink
       NSURL *deviceManager =  [NSURL URLWithString: [[NYPLAccount sharedAccount:self.accountType] licensor][@"deviceManager"]];
       if (deviceManager != nil) {
         [NYPLDeviceManager deleteDevice:[[NYPLAccount sharedAccount:self.accountType] deviceID] url:deviceManager];
       }
     }

     afterDeauthorization();
   }];
  
#endif

}

- (void)validateCredentials
{
  Account *account = [[AccountsManager sharedInstance] account:self.accountType];
  NSMutableURLRequest *const request =
  [NSMutableURLRequest requestWithURL:[[NSURL URLWithString:[account catalogUrl]] URLByAppendingPathComponent:@"loans"]];
  
  request.timeoutInterval = 20.0;
  
  NSURLSessionDataTask *const task =
  [self.session
   dataTaskWithRequest:request
   completionHandler:^(NSData *data,
                       NSURLResponse *const response,
                       NSError *const error) {

     NSInteger const statusCode = ((NSHTTPURLResponse *) response).statusCode;

     if(statusCode == 200) {
       
#if defined(FEATURE_DRM_CONNECTOR)

       NYPLXML *loansXML = [NYPLXML XMLWithData:data];
       NYPLOPDSFeed *loansFeed = [[NYPLOPDSFeed alloc] initWithXML:loansXML];
       
       if (loansFeed.licensor) {
         [[NYPLAccount sharedAccount:self.accountType] setLicensor:loansFeed.licensor];
       } else {
         NYPLLOG(@"Login Failed: No Licensor Token received or parsed from OPDS Loans feed");
         [self authorizationAttemptDidFinish:NO error:nil];
         return;
       }
       
       NSMutableArray *licensorItems = [[loansFeed.licensor[@"clientToken"] stringByReplacingOccurrencesOfString:@"\n" withString:@""] componentsSeparatedByString:@"|"].mutableCopy;
       NSString *tokenPassword = [licensorItems lastObject];
       [licensorItems removeLastObject];
       NSString *tokenUsername = [licensorItems componentsJoinedByString:@"|"];
       
       NYPLLOG(@"***DRM Auth/Activation Attempt***");
       NYPLLOG_F(@"\nLicensor: %@\n",loansFeed.licensor);
       NYPLLOG_F(@"Token Username: %@\n",tokenUsername);
       NYPLLOG_F(@"Token Password: %@\n",tokenPassword);
       
       [[NYPLADEPT sharedInstance]
        authorizeWithVendorID:[[NYPLAccount sharedAccount:self.accountType] licensor][@"vendor"]
        username:tokenUsername
        password:tokenPassword
        completion:^(BOOL success, NSError *error, NSString *deviceID, NSString *userID) {

          NYPLLOG_F(@"Activation Success: %@\n", success ? @"Yes" : @"No");
          NYPLLOG_F(@"Error: %@\n",error.localizedDescription);
          NYPLLOG_F(@"UserID: %@\n",userID);
          NYPLLOG_F(@"DeviceID: %@\n",deviceID);
          NYPLLOG(@"***DRM Auth/Activation Completion***");
          
          if (success) {
            // POST deviceID to adobeDevicesLink
            NSURL *deviceManager = [NSURL URLWithString: [[NYPLAccount sharedAccount:self.accountType] licensor][@"deviceManager"]];
            if (deviceManager != nil) {
              [NYPLDeviceManager postDevice:deviceID url:deviceManager];
            }
            
            [[NSOperationQueue mainQueue] addOperationWithBlock:^{
              [[NYPLAccount sharedAccount:self.accountType] setUserID:userID];
              [[NYPLAccount sharedAccount:self.accountType] setDeviceID:deviceID];
            }];
          }
          
          [self authorizationAttemptDidFinish:success error:error];
          
        }];

#else
       
       [self authorizationAttemptDidFinish:YES error:nil];
       
#endif

       return;
     }
     
     [self removeActivityTitle];
     [[UIApplication sharedApplication] endIgnoringInteractionEvents];
     
     if (error.code == NSURLErrorCancelled) {
       // We cancelled the request when asked to answer the server's challenge a second time
       // because we don't have valid credentials.
       self.PINTextField.text = @"";
       [self textFieldsDidChange];
       [self.PINTextField becomeFirstResponder];
     }
     
     if (statusCode == 401) {
       NSError *error401 = [[NSError alloc] initWithDomain:NSURLErrorDomain code:NSURLErrorCancelled userInfo:nil];
       [self showLoginAlertWithError:error401];
       return;
     }
     [self showLoginAlertWithError:error];
     
   }];
  
  [task resume];
}

- (void)showLoginAlertWithError:(NSError *)error
{
  [[NYPLRootTabBarController sharedController] safelyPresentViewController:
   [NYPLAlertController alertWithTitle:@"SettingsAccountViewControllerLoginFailed" error:error]
                                                                  animated:YES
                                                                completion:nil];
  [self removeActivityTitle];
}

- (void)showLogoutAlertWithError:(NSError *)error responseCode:(NSInteger)code
{
  NSString *title; NSString *message;
  if (code == 401) {
    title = @"Unexpected Credentials";
    message = @"Your username or password may have changed since the last time you logged in.\n\nIf you believe this is an error, please contact your library.";
    [self deauthorizeDevice];
  } else if (error) {
    title = @"SettingsAccountViewControllerLogoutFailed";
    message = error.localizedDescription;
  } else {
    title = @"SettingsAccountViewControllerLogoutFailed";
    message = NSLocalizedString(@"An unknown error occurred while trying to sign out.", nil);
  }
  [self presentViewController:[NYPLAlertController alertWithTitle:title message:message]
                     animated:YES
                   completion:nil];
}

- (void)authorizationAttemptDidFinish:(BOOL)success error:(NSError *)error
{
  [[NSOperationQueue mainQueue] addOperationWithBlock:^{
    [self removeActivityTitle];
    [[UIApplication sharedApplication] endIgnoringInteractionEvents];
    
    if(success) {
      [[NSOperationQueue mainQueue] addOperationWithBlock:^{

        [self checkSyncSetting];
      
      }];
      
      [[NYPLAccount sharedAccount:self.accountType] setBarcode:self.barcodeTextField.text
                                                           PIN:self.PINTextField.text];
      
      if(self.accountType == [[NYPLSettings sharedSettings] currentAccountIdentifier]) {
        void (^handler)() = self.completionHandler;
        self.completionHandler = nil;
        if(handler) handler();
        [[NSNotificationCenter defaultCenter] postNotificationName:NYPLSyncBeganNotification object:nil];
        [[NYPLBookRegistry sharedRegistry] syncWithCompletionHandler:^(BOOL __unused success) {
          [[NSNotificationCenter defaultCenter] postNotificationName:NYPLSyncEndedNotification object:nil];
        }];
      }
      
    } else {
      [[NSNotificationCenter defaultCenter] postNotificationName:NYPLSyncEndedNotification object:nil];
      [self showLoginAlertWithError:error];
    }
  }];
}

- (void)bugsnagLogInvalidLicensor
{
  [Bugsnag notifyError:[NSError errorWithDomain:@"org.nypl.labs.SimplyE" code:3 userInfo:nil]
                 block:^(BugsnagCrashReport * _Nonnull report) {
                   report.context = @"NYPLSettingsAccountDetailViewController";
                   report.severity = BSGSeverityWarning;
                   report.errorMessage = @"No Valid Licensor available to deauthorize device. Signing out NYPLAccount credentials anyway with no message to the user.";
                   NSDictionary *metadata = @{@"accountTypeID" : @(self.accountType)};
                   [report addMetadata:metadata toTabWithName:@"Extra Data"];
                 }];
}

#pragma mark - UITableViewDelegate

- (void)tableView:(__attribute__((unused)) UITableView *)tableView
didSelectRowAtIndexPath:(NSIndexPath *const)indexPath
{
  NSArray *sectionArray = (NSArray *)self.tableData[indexPath.section];
  CellKind cellKind = (CellKind)[sectionArray[indexPath.row] intValue];
  
  switch(cellKind) {
    case CellKindAgeCheck: {
      UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
      if (self.account.userAboveAgeLimit == YES) {
        [self confirmAgeChange:^(BOOL under13) {
          if (under13) {
            cell.accessoryView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"CheckboxOff"]];
            self.account.userAboveAgeLimit = NO;
            //Delete Books in My Books
            [[NYPLMyBooksDownloadCenter sharedDownloadCenter] reset:self.accountType];
            [[NYPLBookRegistry sharedRegistry] reset:self.accountType];
            NYPLCatalogNavigationController *catalog = (NYPLCatalogNavigationController*)[NYPLRootTabBarController sharedController].viewControllers[0];
            [catalog popToRootViewControllerAnimated:NO];
            [catalog reloadSelectedLibraryAccount];
          }
        }];
      } else {
        cell.accessoryView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"CheckboxOn"]];
        self.account.userAboveAgeLimit = YES;
        NYPLCatalogNavigationController *catalog = (NYPLCatalogNavigationController*)[NYPLRootTabBarController sharedController].viewControllers[0];
        [catalog popToRootViewControllerAnimated:NO];
        [catalog reloadSelectedLibraryAccount];
      }
      break;
    }
    case CellKindBarcode:
      [self.barcodeTextField becomeFirstResponder];
      break;
    case CellKindPIN:
      [self.PINTextField becomeFirstResponder];
      break;
    case CellKindLogInSignOut:
      [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
      if([[NYPLAccount sharedAccount:self.accountType] hasBarcodeAndPIN]) {
        UIAlertController *const alertController =
        (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad &&
         (self.traitCollection.horizontalSizeClass != UIUserInterfaceSizeClassCompact))
         ? [UIAlertController
            alertControllerWithTitle:NSLocalizedString(@"SignOut", nil)
            message:NSLocalizedString(@"SettingsAccountViewControllerLogoutMessage", nil)
            preferredStyle:UIAlertControllerStyleAlert]
         : [UIAlertController
            alertControllerWithTitle:
            NSLocalizedString(@"SettingsAccountViewControllerLogoutMessage", nil)
            message:nil
            preferredStyle:UIAlertControllerStyleActionSheet];
        alertController.popoverPresentationController.sourceRect = self.view.bounds;
        alertController.popoverPresentationController.sourceView = self.view;
        [alertController addAction:[UIAlertAction
                                    actionWithTitle:NSLocalizedString(@"SignOut", nil)
                                    style:UIAlertActionStyleDestructive
                                    handler:^(__attribute__((unused)) UIAlertAction *action) {
                                      [self logOut];
                                    }]];
        [alertController addAction:[UIAlertAction
                                    actionWithTitle:NSLocalizedString(@"Cancel", nil)
                                    style:UIAlertActionStyleCancel
                                    handler:nil]];
        [self presentViewController:alertController animated:YES completion:^{
          alertController.view.tintColor = [NYPLConfiguration mainColor];
        }];
      } else {
        [self logIn];
      }
      break;
    case CellKindRegistration: {
      [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
      
      if (self.account.supportsCardCreator) {

      __weak NYPLSettingsAccountDetailViewController *const weakSelf = self;
      CardCreatorConfiguration *const configuration =
      [[CardCreatorConfiguration alloc]
       initWithEndpointURL:[APIKeys cardCreatorEndpointURL]
       endpointVersion:[APIKeys cardCreatorVersion]
       endpointUsername:[APIKeys cardCreatorUsername]
       endpointPassword:[APIKeys cardCreatorPassword]
       requestTimeoutInterval:20.0
       completionHandler:^(NSString *const username, NSString *const PIN, BOOL const userInitiated) {
         if (userInitiated) {
           // Dismiss CardCreator when user finishes Credential Review
           [weakSelf dismissViewControllerAnimated:YES completion:nil];
         } else {
           weakSelf.barcodeTextField.text = username;
           weakSelf.PINTextField.text = PIN;
           [weakSelf updateLoginLogoutCellAppearance];
           self.isLoggingInAfterSignUp = YES;
           [weakSelf logIn];
         }
       }];
      
      UINavigationController *const navigationController =
      [CardCreator initialNavigationControllerWithConfiguration:configuration];
      navigationController.navigationBar.topItem.leftBarButtonItem =
      [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Cancel", nil)
                                       style:UIBarButtonItemStylePlain
                                      target:self
                                      action:@selector(didSelectCancelForSignUp)];
      navigationController.modalPresentationStyle = UIModalPresentationFormSheet;
      [self presentViewController:navigationController animated:YES completion:nil];
      
      }
      else
      {
        
        RemoteHTMLViewController *webViewController = [[RemoteHTMLViewController alloc] initWithURL:[[NSURL alloc] initWithString:self.account.cardCreatorUrl] title:@"eCard" failureMessage:NSLocalizedString(@"SettingsConnectionFailureMessage", nil)];
        
        UINavigationController *const navigationController = [[UINavigationController alloc] initWithRootViewController:webViewController];
        
        navigationController.navigationBar.topItem.leftBarButtonItem =
        [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Close", nil)
                                         style:UIBarButtonItemStylePlain
                                        target:self
                                        action:@selector(didSelectCancelForSignUp)];
        navigationController.modalPresentationStyle = UIModalPresentationFormSheet;
        [self presentViewController:navigationController animated:YES completion:nil];
        
        
      }
      
      break;
    }
    case CellKindSyncButton: {
      break;
    }
    case CellKindBarcodeImage: {
      break;
    }
    case CellReportIssue: {
      if ([MFMailComposeViewController canSendMail])
      {
        UIStoryboard *sb = [UIStoryboard storyboardWithName:@"ReportIssue" bundle:nil];
        NYPLReportIssueViewController *vc = [sb instantiateViewControllerWithIdentifier:@"ReportIssueController"];
        vc.account = self.account;
        [self.navigationController pushViewController:vc animated:YES];
      }
      else
      {
        [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
        UIAlertView *alert = [[UIAlertView alloc]
                              initWithTitle:@"No email account is set for this device. "
                              message:[NSString stringWithFormat:@"If you have web email, contact %@ to report an issue.", self.account.supportEmail]
                              delegate:nil
                              cancelButtonTitle:nil
                              otherButtonTitles:@"OK", nil];
        [alert show];
      }
      break;
    }
    case CellSupportCenter: {
      
      [[HSHelpStack instance] setThemeFrompList:@"HelpStackThemeNYPL"];

      HSDeskGear *deskGear = [[HSDeskGear alloc]
                              initWithInstanceBaseUrl:[APIKeys helpstackBaseUrl]
                              token:[APIKeys helpstackToken]
                              andBrand:nil];
      
      HSHelpStack *helpStack = [HSHelpStack instance];
      helpStack.gear = deskGear;
    
      if(UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad &&
         self.traitCollection.horizontalSizeClass != UIUserInterfaceSizeClassCompact) {
        UIStoryboard* helpStoryboard = [UIStoryboard storyboardWithName:@"HelpStackStoryboard" bundle:[NSBundle mainBundle]];
        UINavigationController *mainNavVC = [helpStoryboard instantiateInitialViewController];
        UIViewController *firstVC = mainNavVC.viewControllers.firstObject;
        firstVC.navigationItem.leftBarButtonItem = nil;
        [self.navigationController pushViewController:firstVC animated:true];

      } else {
        [[HSHelpStack instance] showHelp:self];
      }
      break;
    }
    case CellKindAbout: {
      RemoteHTMLViewController *vc = [[RemoteHTMLViewController alloc]
                                      initWithURL:[self.account getLicenseURL:URLTypeAcknowledgements]
                                      title:NSLocalizedString(@"About", nil)
                                      failureMessage:NSLocalizedString(@"SettingsConnectionFailureMessage", nil)];
      [self.navigationController pushViewController:vc animated:true];
      break;
    }
    case CellKindPrivacyPolicy: {
      RemoteHTMLViewController *vc = [[RemoteHTMLViewController alloc]
                                      initWithURL:[self.account getLicenseURL:URLTypePrivacyPolicy]
                                      title:NSLocalizedString(@"PrivacyPolicy", nil)
                                      failureMessage:NSLocalizedString(@"SettingsConnectionFailureMessage", nil)];
      [self.navigationController pushViewController:vc animated:true];
      break;
    }
    case CellKindContentLicense: {
      RemoteHTMLViewController *vc = [[RemoteHTMLViewController alloc]
                                      initWithURL:[self.account getLicenseURL:URLTypeContentLicenses]
                                      title:NSLocalizedString(@"ContentLicenses", nil)
                                      failureMessage:NSLocalizedString(@"SettingsConnectionFailureMessage", nil)];
      [self.navigationController pushViewController:vc animated:true];
      break;
    }
  }
}

- (void)showDetailVC:(UIViewController *)vc fromIndexPath:(NSIndexPath *)indexPath
{
  if(UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad &&
     self.traitCollection.horizontalSizeClass != UIUserInterfaceSizeClassCompact) {
    [self.splitViewController showDetailViewController:[[UINavigationController alloc]
                                                        initWithRootViewController:vc]
                                                sender:self];
  } else {
    [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
    [self.splitViewController showDetailViewController:vc sender:self];
  }
}

- (void)didSelectCancelForSignUp
{
  [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark UITableViewDataSource

- (UITableViewCell *)tableView:(__attribute__((unused)) UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *const)indexPath
{
  NSArray *sectionArray = (NSArray *)self.tableData[indexPath.section];
  CellKind cellKind = (CellKind)[sectionArray[indexPath.row] intValue];
  
  switch(cellKind) {
    case CellKindBarcode: {
      UITableViewCell *const cell = [[UITableViewCell alloc]
                                     initWithStyle:UITableViewCellStyleDefault
                                     reuseIdentifier:nil];
      cell.selectionStyle = UITableViewCellSelectionStyleNone;
      {
        self.barcodeTextField.font = [UIFont customFontForTextStyle:UIFontTextStyleBody];
        [cell.contentView addSubview:self.barcodeTextField];
        self.barcodeTextField.preservesSuperviewLayoutMargins = YES;
        [self.barcodeTextField autoPinEdgeToSuperviewMargin:ALEdgeRight];
        [self.barcodeTextField autoPinEdgeToSuperviewMargin:ALEdgeLeft];
        [self.barcodeTextField autoConstrainAttribute:ALAttributeTop toAttribute:ALAttributeMarginTop
                                               ofView:[self.barcodeTextField superview]
                                           withOffset:verticalMarginPadding];
        [self.barcodeTextField autoConstrainAttribute:ALAttributeBottom toAttribute:ALAttributeMarginBottom
                                               ofView:[self.barcodeTextField superview]
                                           withOffset:-verticalMarginPadding];
      }
      return cell;
    }
    case CellKindBarcodeImage:{
      UITableViewCell *const cell = [[UITableViewCell alloc]
                                     initWithStyle:UITableViewCellStyleDefault
                                     reuseIdentifier:nil];
      cell.selectionStyle = UITableViewCellSelectionStyleNone;
      self.barcodeLabelImage = [[UILabel alloc] initWithFrame:CGRectMake(0, 20, self.view.bounds.size.width, 140)];
      self.barcodeLabelImage.text = [NSString stringWithFormat:@"A%@B", [NYPLAccount sharedAccount:self.accountType].authorizationIdentifier];
      self.barcodeLabelImage.font = [UIFont fontWithName:@"CodabarLarge" size:36.0];
      self.barcodeLabelImage.textAlignment = NSTextAlignmentCenter;
      self.barcodeLabelImage.adjustsFontSizeToFitWidth = YES;
      UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(barcodeZoom)];
      
      [self.barcodeLabelImage addGestureRecognizer:tap];
      self.barcodeLabelImage.userInteractionEnabled = YES;

      [cell.contentView addSubview:self.barcodeLabelImage];
      
      UILabel *labelD = [[UILabel alloc] initWithFrame:CGRectMake(0, 95, self.view.bounds.size.width, 10)];
      labelD.text =  [NYPLAccount sharedAccount:self.accountType].authorizationIdentifier;
      labelD.font = [UIFont systemFontOfSize:10];
      labelD.textAlignment = NSTextAlignmentCenter;
      labelD.adjustsFontSizeToFitWidth = YES;
      [cell.contentView addSubview:labelD];

      

      return cell;
    }
    case CellKindPIN: {
      UITableViewCell *const cell = [[UITableViewCell alloc]
                                     initWithStyle:UITableViewCellStyleDefault
                                     reuseIdentifier:nil];
      cell.selectionStyle = UITableViewCellSelectionStyleNone;
      {
        self.PINTextField.font = [UIFont customFontForTextStyle:UIFontTextStyleBody];
        [cell.contentView addSubview:self.PINTextField];
        self.PINTextField.preservesSuperviewLayoutMargins = YES;
        [self.PINTextField autoPinEdgeToSuperviewMargin:ALEdgeRight];
        [self.PINTextField autoPinEdgeToSuperviewMargin:ALEdgeLeft];
        [self.PINTextField autoConstrainAttribute:ALAttributeTop toAttribute:ALAttributeMarginTop
                                           ofView:[self.PINTextField superview]
                                       withOffset:2.0];
        [self.PINTextField autoConstrainAttribute:ALAttributeBottom toAttribute:ALAttributeMarginBottom
                                           ofView:[self.PINTextField superview]
                                       withOffset:-2.0];
      }
      return cell;
    }
    case CellKindLogInSignOut: {
      if(!self.logInSignOutCell) {
        self.logInSignOutCell = [[UITableViewCell alloc]
                                initWithStyle:UITableViewCellStyleDefault
                                reuseIdentifier:nil];
        self.logInSignOutCell.textLabel.font = [UIFont customFontForTextStyle:UIFontTextStyleBody];
      }
      [self updateLoginLogoutCellAppearance];
      return self.logInSignOutCell;
    }
    case CellKindRegistration: {
      return [self createRegistrationCell];
    }
    case CellKindAgeCheck: {
      self.ageCheckCell = [[UITableViewCell alloc]
                           initWithStyle:UITableViewCellStyleDefault
                           reuseIdentifier:nil];
      if (self.account.userAboveAgeLimit) {
        self.ageCheckCell.accessoryView = [[UIImageView alloc] initWithImage:
                                           [UIImage imageNamed:@"CheckboxOn"]];
      } else {
        self.ageCheckCell.accessoryView = [[UIImageView alloc] initWithImage:
                                           [UIImage imageNamed:@"CheckboxOff"]];
      }
      self.ageCheckCell.selectionStyle = UITableViewCellSelectionStyleNone;
      self.ageCheckCell.textLabel.font = [UIFont systemFontOfSize:13];
      self.ageCheckCell.textLabel.text = NSLocalizedString(@"SettingsAccountAgeCheckbox",
                                                           @"Statement that confirms if a user meets the age requirement to download books");
      self.ageCheckCell.textLabel.numberOfLines = 2;
      return self.ageCheckCell;
    }
    case CellKindSyncButton: {
      UITableViewCell *const cell = [[UITableViewCell alloc]
                                     initWithStyle:UITableViewCellStyleDefault
                                     reuseIdentifier:nil];
      if (self.account.syncIsEnabled) {
        [self.switchView setOn:YES];
      } else {
        [self.switchView setOn:NO];
      }
      cell.accessoryView = self.switchView;
      [self.switchView addTarget:self action:@selector(syncSwitchChanged:) forControlEvents:UIControlEventValueChanged];
      [cell.contentView addSubview:self.switchView];
      cell.selectionStyle = UITableViewCellSelectionStyleNone;
      cell.textLabel.font = [UIFont customFontForTextStyle:UIFontTextStyleBody];
      cell.textLabel.text = NSLocalizedString(@"SettingsAccountSyncTitle",
                                              @"Title for switch to turn on or off syncing.");
      return cell;
    }
    case CellReportIssue: {
      UITableViewCell *cell = [[UITableViewCell alloc]
                               initWithStyle:UITableViewCellStyleDefault
                               reuseIdentifier:nil];
      cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
      cell.textLabel.font = [UIFont customFontForTextStyle:UIFontTextStyleBody];
      cell.textLabel.text = NSLocalizedString(@"Report an Issue", nil);
      return cell;
    }
    case CellSupportCenter: {
      UITableViewCell *cell = [[UITableViewCell alloc]
                               initWithStyle:UITableViewCellStyleDefault
                               reuseIdentifier:nil];
      cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
      cell.textLabel.font = [UIFont customFontForTextStyle:UIFontTextStyleBody];
      cell.textLabel.text = NSLocalizedString(@"Support Center", nil);
      return cell;
    }
    case CellKindAbout: {
      UITableViewCell *cell = [[UITableViewCell alloc]
                                     initWithStyle:UITableViewCellStyleDefault
                                     reuseIdentifier:nil];
      cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
      cell.textLabel.font = [UIFont customFontForTextStyle:UIFontTextStyleBody];
      cell.textLabel.text = [NSString stringWithFormat:@"About %@",self.account.name];
      cell.hidden = ([self.account getLicenseURL:URLTypeAcknowledgements]) ? NO : YES;
      return cell;
    }
    case CellKindPrivacyPolicy: {
      UITableViewCell *cell = [[UITableViewCell alloc]
                                     initWithStyle:UITableViewCellStyleDefault
                                     reuseIdentifier:nil];
      cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
      cell.textLabel.font = [UIFont customFontForTextStyle:UIFontTextStyleBody];
      cell.textLabel.text = NSLocalizedString(@"PrivacyPolicy", nil);
      cell.hidden = ([self.account getLicenseURL:URLTypePrivacyPolicy]) ? NO : YES;
      return cell;
    }
    case CellKindContentLicense: {
      UITableViewCell *cell = [[UITableViewCell alloc]
                                     initWithStyle:UITableViewCellStyleDefault
                                     reuseIdentifier:nil];
      cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
      cell.textLabel.font = [UIFont customFontForTextStyle:UIFontTextStyleBody];
      cell.textLabel.text = NSLocalizedString(@"ContentLicenses", nil);
      cell.hidden = ([self.account getLicenseURL:URLTypeContentLicenses]) ? NO : YES;
      return cell;
    }
    default: {
      return nil;
    }
  }
}

- (UITableViewCell *)createRegistrationCell
{
  UIView *containerView = [[UIView alloc] init];
  UILabel *regTitle = [[UILabel alloc] init];
  UILabel *regButton = [[UILabel alloc] init];

  regTitle.font = [UIFont customFontForTextStyle:UIFontTextStyleBody];
  regTitle.numberOfLines = 2;
  regTitle.text = NSLocalizedString(@"SettingsAccountRegistrationTitle", @"Title for registration. Asking the user if they already have a library card.");
  regButton.font = [UIFont customFontForTextStyle:UIFontTextStyleBody];
  regButton.text = NSLocalizedString(@"SignUp", nil);
  regButton.textColor = [NYPLConfiguration mainColor];

  [containerView addSubview:regTitle];
  [containerView addSubview:regButton];
  [regTitle autoPinEdgeToSuperviewMargin:ALEdgeLeft];
  [regTitle autoConstrainAttribute:ALAttributeTop toAttribute:ALAttributeMarginTop ofView:[regTitle superview] withOffset:verticalMarginPadding];
  [regTitle autoConstrainAttribute:ALAttributeBottom toAttribute:ALAttributeMarginBottom ofView:[regTitle superview] withOffset:-verticalMarginPadding];
  [regButton autoPinEdge:ALEdgeLeft toEdge:ALEdgeRight ofView:regTitle withOffset:8.0 relation:NSLayoutRelationGreaterThanOrEqual];
  [regButton autoPinEdgeToSuperviewMargin:ALEdgeRight];
  [regButton autoAlignAxisToSuperviewMarginAxis:ALAxisHorizontal];
  [regButton setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];

  UITableViewCell *cell = [[UITableViewCell alloc] init];
  [cell.contentView addSubview:containerView];
  containerView.preservesSuperviewLayoutMargins = YES;
  [containerView autoPinEdgesToSuperviewEdges];
  return cell;
}

- (NSInteger)numberOfSectionsInTableView:(__attribute__((unused)) UITableView *)tableView
{
  return self.tableData.count;
}

- (NSInteger)tableView:(__attribute__((unused)) UITableView *)tableView
 numberOfRowsInSection:(NSInteger const)section
{
  if (section > (int)self.tableData.count - 1) {
    return 0;
  } else {
    return [(NSArray *)self.tableData[section] count];
  }
}

- (CGFloat)tableView:(__unused UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
  if (section == 0) {
    return UITableViewAutomaticDimension;
  } else {
    return 0;
  }
}
- (CGFloat)tableView:(__unused UITableView *)tableView heightForFooterInSection:(__unused NSInteger)section
{
  return UITableViewAutomaticDimension;
}
-(NSString *)tableView:(__unused UITableView *)tableView titleForFooterInSection:(NSInteger)section
{
  if (self.account.supportsSimplyESync && [self syncButtonShouldBeVisible] && section == 1) {
  return NSLocalizedString(@"SettingsAccountSyncSubTitle",
                           @"Disclaimer for switch to turn on or off syncing.");
  }
  return nil;
}
-(CGFloat)tableView:(__unused UITableView *)tableView estimatedHeightForHeaderInSection:(NSInteger)section
{
  if (section == 0) {
    return 80;
  } else {
    return 0;
  }
}
- (CGFloat)tableView:(__unused UITableView *)tableView estimatedHeightForFooterInSection:(__unused NSInteger)section
{
  return 44;
}

- (CGFloat)tableView:(__unused UITableView *)tableView estimatedHeightForRowAtIndexPath:(__unused NSIndexPath *)indexPath
{
  return 44;
}
-(CGFloat)tableView:(__unused UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
  NSArray *sectionArray = (NSArray *)self.tableData[indexPath.section];
  CellKind cellKind = (CellKind)[sectionArray[indexPath.row] intValue];
  
  if (cellKind == CellKindBarcodeImage)
  {
    NSLog(@"barcode");
    return 120;
  }
  return UITableViewAutomaticDimension;

}

- (UIView *)tableView:(__unused UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
  if (section == 0) {
    Account *account = [[AccountsManager sharedInstance] account:self.accountType];
    
    UIView *containerView = [[UIView alloc] init];
    containerView.preservesSuperviewLayoutMargins = YES;
    UILabel *titleLabel = [[UILabel alloc] init];
    UILabel *subtitleLabel = [[UILabel alloc] init];
    subtitleLabel.numberOfLines = 0;
    UIImageView *logoView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:account.logo]];
    logoView.contentMode = UIViewContentModeScaleAspectFit;
    
    titleLabel.text = account.name;
    titleLabel.font = [UIFont systemFontOfSize:14];
    subtitleLabel.text = account.subtitle;
    subtitleLabel.font = [UIFont fontWithName:@"AvenirNext-Regular" size:12];
    
    [containerView addSubview:titleLabel];
    [containerView addSubview:subtitleLabel];
    [containerView addSubview:logoView];
    
    [logoView autoSetDimensionsToSize:CGSizeMake(45, 45)];
    [logoView autoPinEdgeToSuperviewMargin:ALEdgeLeft];
    [logoView autoPinEdgeToSuperviewEdge:ALEdgeTop withInset:16];
    
    [titleLabel autoPinEdgeToSuperviewEdge:ALEdgeTop withInset:16];
    [titleLabel autoPinEdgeToSuperviewMargin:ALEdgeRight];
    [titleLabel autoPinEdge:ALEdgeLeft toEdge:ALEdgeRight ofView:logoView withOffset:8];
    
    [subtitleLabel autoPinEdge:ALEdgeLeft toEdge:ALEdgeLeft ofView:titleLabel];
    [subtitleLabel autoPinEdge:ALEdgeRight toEdge:ALEdgeRight ofView:titleLabel];
    [subtitleLabel autoPinEdge:ALEdgeTop toEdge:ALEdgeBottom ofView:titleLabel withOffset:0];
    [subtitleLabel autoPinEdgeToSuperviewEdge:ALEdgeBottom withInset:20];
    
    return containerView;
  } else {
    return nil;
  }
}

- (UIView *)tableView:(UITableView *)__unused tableView viewForFooterInSection:(NSInteger)section
{
  if (section == 0 && [self.account getLicenseURL:URLTypeEula]) {
    UIView *container = [[UIView alloc] init];
    container.preservesSuperviewLayoutMargins = YES;
    UILabel *footerLabel = [[UILabel alloc] init];
    footerLabel.font = [UIFont customFontForTextStyle:UIFontTextStyleCaption1];
    footerLabel.textColor = [UIColor lightGrayColor];
    footerLabel.numberOfLines = 0;
    footerLabel.userInteractionEnabled = YES;

    NSMutableAttributedString *eulaString = [[NSMutableAttributedString alloc]
                                             initWithString:NSLocalizedString(@"By signing in, you agree to the ", nil) attributes:nil];
    NSDictionary *linkAttributes = @{ NSForegroundColorAttributeName :
                                        [UIColor colorWithRed:0.05 green:0.4 blue:0.65 alpha:1.0],
                                      NSUnderlineStyleAttributeName :
                                        @(NSUnderlineStyleSingle) };
    NSMutableAttributedString *linkString = [[NSMutableAttributedString alloc]
                                             initWithString:@"End User License Agreement." attributes:linkAttributes];
    [eulaString appendAttributedString:linkString];

    footerLabel.attributedText = eulaString;
    [footerLabel addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(showEULA)]];

    [container addSubview:footerLabel];
    [footerLabel autoPinEdgeToSuperviewMargin:ALEdgeLeft];
    [footerLabel autoPinEdgeToSuperviewMargin:ALEdgeRight];
    [footerLabel autoPinEdgeToSuperviewEdge:ALEdgeTop withInset:8.0];
    [footerLabel autoPinEdgeToSuperviewEdge:ALEdgeBottom withInset:16.0 relation:NSLayoutRelationGreaterThanOrEqual];

    return container;

  } else {
    return nil;
  }
}

- (BOOL)textFieldShouldBeginEditing:(__unused UITextField *)textField
{
  return ![[NYPLAccount sharedAccount:self.accountType] hasBarcodeAndPIN];
}

#pragma mark NSURLSessionDelegate

- (void)URLSession:(__attribute__((unused)) NSURLSession *)session
              task:(__attribute__((unused)) NSURLSessionTask *)task
didReceiveChallenge:(NSURLAuthenticationChallenge *const)challenge
 completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition disposition,
                             NSURLCredential *credential))completionHandler
{
  NYPLBasicAuthCustomHandler(challenge,
                             completionHandler,
                             self.barcodeTextField.text,
                             self.PINTextField.text);
}

#pragma mark UITextFieldDelegate

- (BOOL)textField:(UITextField *)textField
shouldChangeCharactersInRange:(NSRange)range
replacementString:(NSString *)string
{
  if(![string canBeConvertedToEncoding:NSASCIIStringEncoding]) {
    return NO;
  }
  
  if(textField == self.barcodeTextField) {
    // Barcodes are numeric and usernames are alphanumeric.
    if([string stringByTrimmingCharactersInSet:[NSCharacterSet alphanumericCharacterSet]].length > 0) {
      return NO;
    }
    
    // Usernames cannot be longer than 25 characters.
    if([textField.text stringByReplacingCharactersInRange:range withString:string].length > 25) {
      return NO;
    }
  }
  
  if(textField == self.PINTextField) {
    if([string stringByTrimmingCharactersInSet:[NSCharacterSet decimalDigitCharacterSet]].length > 0) {
      return NO;
    }
    
    if([textField.text stringByReplacingCharactersInRange:range withString:string].length > 4) {
      return NO;
    }
  }

  return YES;
}

- (void)textFieldsDidChange
{
  [self updateLoginLogoutCellAppearance];
}

- (void)keyboardWillHide
{
  self.registrationCell.textLabel.enabled = YES;
  self.registrationCell.detailTextLabel.enabled = YES;
  self.registrationCell.userInteractionEnabled = YES;
}

- (void)keyboardDidShow:(NSNotification *const)notification
{
  self.registrationCell.textLabel.enabled = NO;
  self.registrationCell.detailTextLabel.enabled = NO;
  self.registrationCell.userInteractionEnabled = NO;
  
  // This nudges the scroll view up slightly so that the log in button is clearly visible even on
  // older 3:2 iPhone displays. I wish there were a more general way to do this, but this does at
  // least work very well.
  
  [[NSOperationQueue mainQueue] addOperationWithBlock:^{
    if((UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) ||
       (self.traitCollection.horizontalSizeClass == UIUserInterfaceSizeClassCompact &&
        self.traitCollection.verticalSizeClass == UIUserInterfaceSizeClassCompact)) {
      CGSize const keyboardSize =
      [[notification userInfo][UIKeyboardFrameBeginUserInfoKey] CGRectValue].size;
      CGRect visibleRect = self.view.frame;
      visibleRect.size.height -= keyboardSize.height + self.tableView.contentInset.top;
      if(!CGRectContainsPoint(visibleRect,
                              CGPointMake(0, CGRectGetMaxY(self.logInSignOutCell.frame)))) {
        // We use an explicit animation block here because |setContentOffset:animated:| does not seem
        // to work at all.
        [UIView animateWithDuration:0.25 animations:^{
          [self.tableView setContentOffset:CGPointMake(0, -self.tableView.contentInset.top + 20)];
        }];
      }
    }
  }];
}

#pragma mark -

- (void)didSelectReveal
{
  self.hiddenPIN = NO;
  [self.tableView reloadData];
}


- (void)PINShowHideSelected
{
  if(self.PINTextField.text.length > 0 && self.PINTextField.secureTextEntry) {
    LAContext *const context = [[LAContext alloc] init];
    if([context canEvaluatePolicy:LAPolicyDeviceOwnerAuthentication error:NULL]) {
      [context evaluatePolicy:LAPolicyDeviceOwnerAuthentication
              localizedReason:NSLocalizedString(@"SettingsAccountViewControllerAuthenticationReason", nil)
                        reply:^(__unused BOOL success,
                                __unused NSError *_Nullable error) {
                          if(success) {
                            [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                              [self togglePINShowHideState];
                            }];
                          }
                        }];
    } else {
      [self togglePINShowHideState];
    }
  } else {
    [self togglePINShowHideState];
  }
}

- (void)togglePINShowHideState
{
  self.PINTextField.secureTextEntry = !self.PINTextField.secureTextEntry;
  NSString *title = self.PINTextField.secureTextEntry ? @"Show" : @"Hide";
  [self.PINShowHideButton setTitle:NSLocalizedString(title, nil) forState:UIControlStateNormal];
  [self.PINShowHideButton sizeToFit];
  [self.tableView reloadData];
}

- (void)accountDidChange
{
  [[NSOperationQueue mainQueue] addOperationWithBlock:^{
    if([NYPLAccount sharedAccount:self.accountType].hasBarcodeAndPIN) {
      self.barcodeTextField.text = [NYPLAccount sharedAccount:self.accountType].barcode;
      self.barcodeLabelImage.text = [NSString stringWithFormat:@"A%@B", [NYPLAccount sharedAccount:self.accountType].authorizationIdentifier];

      self.barcodeTextField.enabled = NO;
      self.barcodeTextField.textColor = [UIColor grayColor];
      self.PINTextField.text = [NYPLAccount sharedAccount:self.accountType].PIN;
      self.PINTextField.textColor = [UIColor grayColor];
      self.barcodeTextField.rightView.hidden = YES;

    } else {
      self.barcodeTextField.text = nil;
      self.barcodeTextField.enabled = YES;
      self.barcodeTextField.textColor = [UIColor blackColor];
      self.PINTextField.text = nil;
      self.PINTextField.textColor = [UIColor blackColor];
      self.barcodeTextField.rightView.hidden = NO;

    }
    
    [self setupTableData];
    [self.tableView reloadData];
    
    [self updateLoginLogoutCellAppearance];
  }];
}

- (void)updateLoginLogoutCellAppearance
{
  if([[NYPLAccount sharedAccount:self.accountType] hasBarcodeAndPIN]) {
    self.logInSignOutCell.textLabel.text = NSLocalizedString(@"SignOut", nil);
    self.logInSignOutCell.textLabel.textAlignment = NSTextAlignmentCenter;
    self.logInSignOutCell.textLabel.textColor = [NYPLConfiguration mainColor];
    self.logInSignOutCell.userInteractionEnabled = YES;
  } else {
    self.logInSignOutCell.textLabel.text = NSLocalizedString(@"LogIn", nil);
    self.logInSignOutCell.textLabel.textAlignment = NSTextAlignmentLeft;
    BOOL const canLogIn =
      ([self.barcodeTextField.text
        stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]].length &&
       [self.PINTextField.text
        stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]].length);
    if(canLogIn) {
      self.logInSignOutCell.userInteractionEnabled = YES;
      self.logInSignOutCell.textLabel.textColor = [NYPLConfiguration mainColor];
    } else {
      self.logInSignOutCell.userInteractionEnabled = NO;
      self.logInSignOutCell.textLabel.textColor = [UIColor lightGrayColor];
    }
  }
}

- (void)checkSyncSetting
{
  [NYPLAnnotations syncSettingsWithCompletionHandler:^(BOOL exist) {
    
    if (!exist)
    {
      // alert
      
      Account *account = [[AccountsManager sharedInstance] account:self.accountType];
      
      NSString *title = @"SimplyE Sync";
      NSString *message = @"<Initial setup> Synchronize your bookmarks and last reading position across all your SimplyE devices.";
      
      NYPLAlertController *alertController = [NYPLAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleAlert];
      
      
      [alertController addAction:[UIAlertAction actionWithTitle:@"Do not Enable Sync" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction * _Nonnull action) {
        
        // add server update here as well
        [NYPLAnnotations updateSyncSettings:false];
        account.syncIsEnabled = NO;
        self.switchView.on = account.syncIsEnabled;
      }]];
      
      
      [alertController addAction:[UIAlertAction actionWithTitle:@"Enable Sync" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction * _Nonnull action) {
        
        // add server update here as well
        [NYPLAnnotations updateSyncSettings:true];
        account.syncIsEnabled = YES;
        self.switchView.on = account.syncIsEnabled;
        
      }]];
      [[NYPLRootTabBarController sharedController] safelyPresentViewController:alertController
                                                                      animated:YES completion:nil];
      
    }
    
  }];
}
- (void)setActivityTitleWithText:(NSString *)text
{
  UIActivityIndicatorView *const activityIndicatorView =
  [[UIActivityIndicatorView alloc]
   initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
  
  [activityIndicatorView startAnimating];
  
  UILabel *const titleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
  titleLabel.text = text;
  titleLabel.font = [UIFont customFontForTextStyle:UIFontTextStyleBody];
  [titleLabel sizeToFit];
  
  // This view is used to keep the title label centered as in Apple's Settings application.
  UIView *const rightPaddingView = [[UIView alloc] initWithFrame:activityIndicatorView.bounds];
  
  NYPLLinearView *const linearView = [[NYPLLinearView alloc] init];
  linearView.tag = linearViewTag;
  linearView.contentVerticalAlignment = NYPLLinearViewContentVerticalAlignmentMiddle;
  linearView.padding = 5.0;
  [linearView addSubview:activityIndicatorView];
  [linearView addSubview:titleLabel];
  [linearView addSubview:rightPaddingView];
  [linearView sizeToFit];
  [linearView autoSetDimensionsToSize:CGSizeMake(linearView.frame.size.width, linearView.frame.size.height)];
  
  self.logInSignOutCell.textLabel.text = nil;
  if (![self.logInSignOutCell.contentView viewWithTag:linearViewTag]) {
    [self.logInSignOutCell.contentView addSubview:linearView];
  }
  [linearView autoCenterInSuperview];
}

- (void)removeActivityTitle {
  UIView *view = [self.logInSignOutCell.contentView viewWithTag:linearViewTag];
  [view removeFromSuperview];
  [self updateLoginLogoutCellAppearance];
}

- (void)showEULA
{
  UIViewController *eulaViewController = [[NYPLSettingsEULAViewController alloc] initWithAccount:self.account];
  UINavigationController *navVC = [[UINavigationController alloc] initWithRootViewController:eulaViewController];
  [self.navigationController presentViewController:navVC animated:YES completion:nil];
}

- (void)syncSwitchChanged:(UISwitch*)sender
{
  
  Account *account = [[AccountsManager sharedInstance] account:self.accountType];
  NSString *title, *message;
  
  if (account.syncIsEnabled)
  {
    title = @"Disable Sync";
    message = @"Bookmarks and last reading position in this device will not be shared with your other SimplyE devices.";
  }
  else
  {
    title = @"Enable Sync";
    message = @"This will synchronize your bookmarks and last reading position across all your SimplyE devices.";
  }
  
  NYPLAlertController *alertController = [NYPLAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleAlert];
  if (account.syncIsEnabled)
  {
    [alertController addAction:[UIAlertAction actionWithTitle:@"Remove Current Device From Sync" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction * _Nonnull action) {
    
      // add server update here as well
      
      if (sender.on) {
        account.syncIsEnabled = YES;
      } else {
        account.syncIsEnabled = NO;
      }
      self.switchView.on = account.syncIsEnabled;

    }]];
    [alertController addAction:[UIAlertAction actionWithTitle:@"Remove All Devices From Sync" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction * _Nonnull action) {
      
      // add server update here as well
      
      [NYPLAnnotations updateSyncSettings:false];
      if (sender.on) {
        account.syncIsEnabled = YES;
      } else {
        account.syncIsEnabled = NO;
      }
      self.switchView.on = account.syncIsEnabled;
      
    }]];
  }
  else
  {
    [alertController addAction:[UIAlertAction actionWithTitle:@"Enable Sync" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction * _Nonnull action) {
      
      // add server update here as well
      
      [NYPLAnnotations updateSyncSettings:true];
      if (sender.on) {
        account.syncIsEnabled = YES;
      } else {
        account.syncIsEnabled = NO;
      }
      self.switchView.on = account.syncIsEnabled;
      
    }]];
  }
  
  [alertController addAction:[UIAlertAction actionWithTitle:@"Never mind" style:UIAlertActionStyleCancel handler:^(__unused UIAlertAction * _Nonnull action) {

    self.switchView.on = account.syncIsEnabled;
    
  }]];
  
  [[NYPLRootTabBarController sharedController] safelyPresentViewController:alertController
                                                                  animated:YES completion:nil];
}

- (void)setAccountSwitchChanged:(id)sender
{
  UISwitch *switchControl = sender;
  if (switchControl.on) {
    [[AccountsManager sharedInstance] changeCurrentAccountWithIdentifier:self.accountType];
    [self setupTableData];
    [self.tableView reloadData];
  }
}

- (void)confirmAgeChange:(void (^)(BOOL))completion
{
  NYPLAlertController *alertCont = [NYPLAlertController
                                    alertControllerWithTitle:NSLocalizedString(@"Age Verification", @"An alert title indicating the user needs to verify their age")
                                    message:NSLocalizedString(@"SettingsAccountViewControllerAgeCheckMessage",
                                                              @"An alert message warning the user they will lose their downloaded books if they continue.")
                                    preferredStyle:UIAlertControllerStyleAlert];
  
  [alertCont addAction: [UIAlertAction actionWithTitle:NSLocalizedString(@"Under 13", comment: @"A button title indicating an age range")
                                                 style:UIAlertActionStyleDefault
                                               handler:^(UIAlertAction * _Nonnull __unused action) {
                                                 if (completion) { completion(YES); }
                                               }]];
  
  [alertCont addAction: [UIAlertAction actionWithTitle:NSLocalizedString(@"13 or Older", comment: @"A button title indicating an age range")
                                                 style:UIAlertActionStyleDefault
                                               handler:^(UIAlertAction * _Nonnull __unused action) {
                                                 if (completion) { completion(NO); }
                                               }]];
  
  [alertCont presentFromViewControllerOrNil:nil animated:YES completion:nil];
}

- (void)updateShowHidePINState
{
  self.PINTextField.rightView.hidden = YES;
  
  // LAPolicyDeviceOwnerAuthentication is only on iOS >= 9.0
  if([NSProcessInfo processInfo].operatingSystemVersion.majorVersion >= 9) {
    LAContext *const context = [[LAContext alloc] init];
    if([context canEvaluatePolicy:LAPolicyDeviceOwnerAuthentication error:NULL]) {
      self.PINTextField.rightView.hidden = NO;
    }
  }
}

- (BOOL)registrationIsPossible
{
  return ([NYPLConfiguration cardCreationEnabled] &&
          ([[AccountsManager sharedInstance] account:self.accountType].supportsCardCreator  || [[AccountsManager sharedInstance] account:self.accountType].cardCreatorUrl) &&
          ![[NYPLAccount sharedAccount:self.accountType] hasBarcodeAndPIN]);
}

- (BOOL)syncButtonShouldBeVisible
{
  return ([self.account getLicenseURL:URLTypeAnnotations] &&
          [[NYPLAccount sharedAccount:self.accountType] hasBarcodeAndPIN]);
}

- (void)didSelectCancel
{
  [self.navigationController.presentingViewController
   dismissViewControllerAnimated:YES
   completion:nil];
}

#pragma mark - View Controller Methods

- (void)willResignActive
{
  if(!self.PINTextField.secureTextEntry) {
    [self togglePINShowHideState];
  }
}

- (void)willEnterForeground
{
  // We update the state again in case the user enabled or disabled an authentication mechanism.
  [[NSOperationQueue mainQueue] addOperationWithBlock:^{
    [self updateShowHidePINState];
  }];
}

- (void)viewWillTransitionToSize:(__unused CGSize)size
       withTransitionCoordinator:(__unused id<UIViewControllerTransitionCoordinator>)coordinator
{
  [self.tableView reloadData];
}

@end
