import UIKit
import PureLayout


/// Welcome screen for a first-time user
final class NYPLWelcomeScreenViewController: UIViewController {
  
  var completion: (() -> ())?
  
  required init(completion: (() -> ())?) {
    self.completion = completion
    super.init(nibName: nil, bundle: nil)
  }

  @available(*, unavailable)
  required init?(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func viewDidLoad() {
    
    super.viewDidLoad()
    
    self.title = "Welcome Screen"
    self.view.backgroundColor = NYPLConfiguration.backgroundColor()
    
    setupViews()
  }
  
  override func viewWillAppear(animated: Bool) {
    super.viewWillAppear(animated)
    self.navigationController?.setNavigationBarHidden(true, animated: false)
  }
  
  override func viewWillDisappear(animated: Bool) {
    super.viewWillDisappear(animated)
    self.navigationController?.setNavigationBarHidden(false, animated: false)
  }
  
  //MARK -
  
  func setupViews() {
    let view1 = splashScreenView("SplashPickLibraryIcon", headline: "Read Books From Your Library", subheadline: "Check out books and sync across devices", buttonTitle: "PICK YOUR LIBRARY", buttonTargetSelector: #selector(pickYourLibraryTapped))
    
    let view2 = splashScreenView("SplashInstantClassicsIcon", headline: "Read Books Without a Library Card", subheadline: "Find classic books in the public domain", buttonTitle: "INSTANT CLASSICS", buttonTargetSelector: #selector(instantClassicsTapped))
    
    let logoView = UIImageView(image: UIImage(named: "FullLogo"))
    logoView.contentMode = .ScaleAspectFit
    
    let containerView = UIView()
    containerView.addSubview(logoView)
    containerView.addSubview(view1)
    containerView.addSubview(view2)
    
    logoView.autoPinEdgeToSuperviewMargin(.Top)
    logoView.autoAlignAxisToSuperviewAxis(.Vertical)
    logoView.autoSetDimensionsToSize(CGSizeMake(180, 150))
    
    view1.autoAlignAxisToSuperviewAxis(.Vertical)
    view1.autoPinEdge(.Top, toEdge: .Bottom, ofView: logoView, withOffset: 5)
    
    view2.autoAlignAxisToSuperviewAxis(.Vertical)
    view2.autoPinEdge(.Top, toEdge: .Bottom, ofView: view1, withOffset: 8)
    view2.autoPinEdgeToSuperviewEdge(.Bottom, withInset: 80)
    view2.autoPinEdgeToSuperviewMargin(.Left)
    view2.autoPinEdgeToSuperviewMargin(.Right)
    
    
    self.view.addSubview(containerView)
    containerView.autoCenterInSuperview()
  }
  
  func splashScreenView(imageName: String, headline: String, subheadline: String, buttonTitle: String, buttonTargetSelector: Selector) -> UIView {
    let tempView = UIView()
    
    let imageView1 = UIImageView(image: UIImage(named: imageName))
    
    tempView.addSubview(imageView1)
    imageView1.autoSetDimensionsToSize(CGSizeMake(60, 60))
    imageView1.autoAlignAxisToSuperviewMarginAxis(.Vertical)
    imageView1.autoPinEdgeToSuperviewMargin(.Top)
    
    let textLabel1 = UILabel()
    textLabel1.textAlignment = .Center
    textLabel1.text = headline
    textLabel1.font = UIFont.systemFontOfSize(16)
    
    tempView.addSubview(textLabel1)
    textLabel1.autoPinEdge(.Top, toEdge: .Bottom, ofView: imageView1, withOffset: 2.0, relation: .Equal)
    textLabel1.autoPinEdge(.Leading, toEdge: .Leading, ofView: tempView, withOffset: 0.0, relation: .GreaterThanOrEqual)
    textLabel1.autoPinEdge(.Trailing, toEdge: .Trailing, ofView: tempView, withOffset: 0.0, relation: .GreaterThanOrEqual)
    textLabel1.autoAlignAxisToSuperviewMarginAxis(.Vertical)
    
    let textLabel2 = UILabel()
    textLabel2.textAlignment = .Center
    textLabel2.text = subheadline
    textLabel2.font = UIFont.systemFontOfSize(12)

    tempView.addSubview(textLabel2)
    textLabel2.autoPinEdge(.Top, toEdge: .Bottom, ofView: textLabel1, withOffset: 0.0, relation: .Equal)
    textLabel2.autoPinEdge(.Leading, toEdge: .Leading, ofView: tempView, withOffset: 0.0, relation: .GreaterThanOrEqual)
    textLabel2.autoPinEdge(.Trailing, toEdge: .Trailing, ofView: tempView, withOffset: 0.0, relation: .GreaterThanOrEqual)
    textLabel2.autoAlignAxisToSuperviewMarginAxis(.Vertical)
    
    let button = UIButton()
    button.setTitle(buttonTitle, forState: .Normal)
    button.titleLabel?.font = UIFont.systemFontOfSize(12)
    button.setTitleColor(UIColor.init(red: 0.0, green: 122.0/255.0, blue: 1.0, alpha: 1.0), forState: .Normal)
    button.layer.borderColor = UIColor.init(red: 141.0/255.0, green: 199.0/255.0, blue: 64.0/255.0, alpha: 1.0).CGColor
    button.layer.borderWidth = 2
    button.layer.cornerRadius = 6

    button.contentEdgeInsets = UIEdgeInsetsMake(10.0, 10.0, 10.0, 10.0)
    button.addTarget(self, action: buttonTargetSelector, forControlEvents: .TouchUpInside)
    tempView.addSubview(button)
    
    button.autoPinEdge(.Top, toEdge: .Bottom, ofView: textLabel2, withOffset: 6.0, relation: .Equal)
    button.autoAlignAxisToSuperviewMarginAxis(.Vertical)
    button.autoPinEdgeToSuperviewMargin(.Bottom)
    
    return tempView
  }

  func pickYourLibraryTapped() {
    if completion == nil {
      self.dismissViewControllerAnimated(true, completion: nil)
      return
    }
    let accountNYPL = Accounts().account(NYPLUserAccountType.NYPL.rawValue)
    // Existing User
    if NYPLSettings.sharedSettings().userAcceptedEULAForAccount(accountNYPL) == false {
      let listVC = NYPLWelcomeScreenAccountList { libraryAccount in
        NYPLSettings.sharedSettings().currentAccountIdentifier = libraryAccount.id
        self.completion!()
      }
      self.navigationController?.pushViewController(listVC, animated: true)
    } else {
      completion!()
    }
  }
  
  func instantClassicsTapped() {
    //GODO should make dynamic ID for magic library in case someone changes it
    NYPLSettings.sharedSettings().currentAccountIdentifier = NYPLUserAccountType.Magic.rawValue
    if completion != nil {
      completion!()
    }
  }
}


/// List of available Libraries/Accounts to select as patron's primary
/// when going through Welcome Screen flow.
final class NYPLWelcomeScreenAccountList: UITableViewController {
  
  var accounts: [Account]!
  let completion: Account -> ()
  
  required init(completion: Account -> ()) {
    self.completion = completion
    super.init(nibName: nil, bundle: nil)
  }
  
  @available(*, unavailable)
  required init?(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func viewDidLoad() {
    self.accounts = Accounts().accounts
    
//    self.navigationItem.hidesBackButton = true
    self.title = "Pick Your Library"
  }
  
  override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
    completion(accounts[indexPath.row])
  }
  
  override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return self.accounts.count
  }
  
  override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
    var cell = tableView.dequeueReusableCellWithIdentifier("cellID") as UITableViewCell!
    if (cell == nil) {
      cell = UITableViewCell(style:.Default, reuseIdentifier:"cellID")
    }
    cell.textLabel!.text = self.accounts[indexPath.row].name
    return cell
  }
  
}