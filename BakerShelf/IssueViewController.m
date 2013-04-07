//
//  IssueViewController.m
//  Baker
//
//  ==========================================================================================
//
//  Copyright (c) 2010-2012, Davide Casali, Marco Colombo, Alessandro Morandi
//  All rights reserved.
//
//  Redistribution and use in source and binary forms, with or without modification, are
//  permitted provided that the following conditions are met:
//
//  Redistributions of source code must retain the above copyright notice, this list of
//  conditions and the following disclaimer.
//  Redistributions in binary form must reproduce the above copyright notice, this list of
//  conditions and the following disclaimer in the documentation and/or other materials
//  provided with the distribution.
//  Neither the name of the Baker Framework nor the names of its contributors may be used to
//  endorse or promote products derived from this software without specific prior written
//  permission.
//  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY
//  EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
//  OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT
//  SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,
//  INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
//  PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
//  INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
//  LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
//  OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//

#import <QuartzCore/QuartzCore.h>

#import "IssueViewController.h"
#import "SSZipArchive.h"
#import "UIConstants.h"
#ifdef BAKER_NEWSSTAND
#import "PurchasesManager.h"
#endif

#import "UIColor+Extensions.h"
#import "Utils.h"

@implementation IssueViewController

#pragma mark - Synthesis

@synthesize issue;
@synthesize actionButton;
@synthesize archiveButton;
@synthesize progressBar;
@synthesize spinner;
@synthesize loadingLabel;
@synthesize priceLabel;

@synthesize issueCover;
@synthesize titleFont;
@synthesize infoFont;
@synthesize titleLabel;
@synthesize infoLabel;

#pragma mark - Init

- (id)initWithBakerIssue:(BakerIssue *)bakerIssue
{
    self = [super init];
    if (self) {
        self.issue = bakerIssue;
        currentStatus = nil;
        purchaseDelayed = NO;

        #ifdef BAKER_NEWSSTAND
        purchasesManager = [PurchasesManager sharedInstance];
        [self addPurchaseObserver:@selector(handleIssueRestored:) name:@"notification_issue_restored"];

        [self addIssueObserver:@selector(handleDownloadStarted:) name:self.issue.notificationDownloadStartedName];
        [self addIssueObserver:@selector(handleDownloadProgressing:) name:self.issue.notificationDownloadProgressingName];
        [self addIssueObserver:@selector(handleDownloadFinished:) name:self.issue.notificationDownloadFinishedName];
        [self addIssueObserver:@selector(handleDownloadError:) name:self.issue.notificationDownloadErrorName];
        #endif
    }
    return self;
}

#pragma mark - View Lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];

    CGSize cellSize = [IssueViewController getIssueCellSize];

    self.view.frame = CGRectMake(0, 0, cellSize.width, cellSize.height);
    self.view.backgroundColor = [UIColor clearColor];
    self.view.tag = 42;

    UI ui = [IssueViewController getIssueContentMeasures];

    self.issueCover = [UIButton buttonWithType:UIButtonTypeCustom];
    issueCover.frame = CGRectMake(ui.cellPadding, ui.cellPadding, ui.thumbWidth, ui.thumbHeight);
    
    issueCover.backgroundColor = [UIColor colorWithHexString:ISSUES_COVER_BACKGROUND_COLOR];
    issueCover.adjustsImageWhenHighlighted = NO;
    issueCover.adjustsImageWhenDisabled = NO;
        
    issueCover.layer.shadowOpacity = 0.5;
    issueCover.layer.shadowOffset = CGSizeMake(0, 2);
    issueCover.layer.shouldRasterize = YES;
    issueCover.layer.rasterizationScale = [UIScreen mainScreen].scale;
    
    [issueCover addTarget:self action:@selector(actionButtonPressed:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:issueCover];

    // SETUP USED FONTS
    self.titleFont = [UIFont fontWithName:ISSUES_TITLE_FONT size:ISSUES_TITLE_FONT_SIZE];
    self.infoFont = [UIFont fontWithName:ISSUES_INFO_FONT size:ISSUES_INFO_FONT_SIZE];
    UIFont *actionFont = [UIFont fontWithName:ISSUES_ACTION_BUTTON_FONT size:ISSUES_ACTION_BUTTON_FONT_SIZE];
    UIFont *archiveFont = [UIFont fontWithName:ISSUES_ARCHIVE_BUTTON_FONT size:ISSUES_ARCHIVE_BUTTON_FONT_SIZE];

    // SETUP TITLE LABEL
    self.titleLabel = [[[UILabel alloc] init] autorelease];
    titleLabel.textColor = [UIColor colorWithHexString:ISSUES_TITLE_COLOR];
    titleLabel.backgroundColor = [UIColor clearColor];
    titleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    titleLabel.textAlignment = NSTextAlignmentLeft;
    titleLabel.font = titleFont;

    [self.view addSubview:titleLabel];

    // SETUP INFO LABEL
    self.infoLabel = [[[UILabel alloc] init] autorelease];
    infoLabel.textColor = [UIColor colorWithHexString:ISSUES_INFO_COLOR];
    infoLabel.backgroundColor = [UIColor clearColor];
    infoLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    infoLabel.textAlignment = NSTextAlignmentLeft;
    infoLabel.font = infoFont;

    [self.view addSubview:infoLabel];

    // SETUP PRICE LABEL
    self.priceLabel = [[[UILabel alloc] init] autorelease];
    priceLabel.textColor = [UIColor colorWithHexString:ISSUES_PRICE_COLOR];
    priceLabel.backgroundColor = [UIColor clearColor];
    priceLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    priceLabel.textAlignment = NSTextAlignmentLeft;
    priceLabel.font = titleFont;

    [self.view addSubview:priceLabel];

    // SETUP ACTION BUTTON
    self.actionButton = [UIButton buttonWithType:UIButtonTypeCustom];
    actionButton.backgroundColor = [UIColor colorWithHexString:ISSUES_ACTION_BUTTON_BACKGROUND_COLOR];
    actionButton.titleLabel.font = actionFont;

    [actionButton setTitle:NSLocalizedString(@"ACTION_DOWNLOADED_TEXT", nil) forState:UIControlStateNormal];
    [actionButton setTitleColor:[UIColor colorWithHexString:ISSUES_ACTION_BUTTON_COLOR] forState:UIControlStateNormal];
    [actionButton addTarget:self action:@selector(actionButtonPressed:) forControlEvents:UIControlEventTouchUpInside];

    [self.view addSubview:actionButton];

    // SETUP ARCHIVE BUTTON
    self.archiveButton = [UIButton buttonWithType:UIButtonTypeCustom];
    archiveButton.backgroundColor = [UIColor colorWithHexString:ISSUES_ARCHIVE_BUTTON_BACKGROUND_COLOR];
    archiveButton.titleLabel.font = archiveFont;

    [archiveButton setTitle:NSLocalizedString(@"ARCHIVE_TEXT", nil) forState:UIControlStateNormal];
    [archiveButton setTitleColor:[UIColor colorWithHexString:ISSUES_ARCHIVE_BUTTON_COLOR] forState:UIControlStateNormal];
    [archiveButton addTarget:self action:@selector(archiveButtonPressed:) forControlEvents:UIControlEventTouchUpInside];

    #ifdef BAKER_NEWSSTAND
    [self.view addSubview:archiveButton];
    #endif

    // SETUP DOWN/LOADING SPINNER AND LABEL
    self.spinner = [[[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray] autorelease];
    spinner.color = [UIColor colorWithHexString:ISSUES_LOADING_SPINNER_COLOR];
    spinner.backgroundColor = [UIColor clearColor];
    spinner.hidesWhenStopped = YES;

    self.loadingLabel = [[[UILabel alloc] init] autorelease];
    loadingLabel.textColor = [UIColor colorWithHexString:ISSUES_LOADING_LABEL_COLOR];
    loadingLabel.backgroundColor = [UIColor clearColor];
    loadingLabel.textAlignment = NSTextAlignmentLeft;
    loadingLabel.text = NSLocalizedString(@"DOWNLOADING_TEXT", nil);
    loadingLabel.font = actionFont;

    [self.view addSubview:spinner];
    [self.view addSubview:loadingLabel];

    // SETUP PROGRESS BAR
    self.progressBar = [[[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleDefault] autorelease];
    self.progressBar.progressTintColor = [UIColor colorWithHexString:ISSUES_PROGRESSBAR_TINT_COLOR];

    [self.view addSubview:progressBar];

    #ifdef BAKER_NEWSSTAND
    // RESUME PENDING NEWSSTAND DOWNLOAD
    NKLibrary *nkLib = [NKLibrary sharedLibrary];
    for (NKAssetDownload *asset in [nkLib downloadingAssets]) {
        if ([asset.issue.name isEqualToString:self.issue.ID]) {
            NSLog(@"Resuming abandoned Newsstand download: %@", asset.issue.name);
            [self.issue downloadWithAsset:asset];
        }
    }
    #endif

    [self refreshContentWithCache:NO];
}
- (void)refreshContentWithCache:(bool)cache {
    UI ui = [IssueViewController getIssueContentMeasures];
    int heightOffset = ui.cellPadding;
    uint textLineheight = [@"The brown fox jumps over the lazy dog" sizeWithFont:infoFont constrainedToSize:CGSizeMake(MAXFLOAT, MAXFLOAT)].height;

    // SETUP COVER IMAGE
    [self.issue getCoverWithCache:cache andBlock:^(UIImage *image) {
        [issueCover setBackgroundImage:image forState:UIControlStateNormal];
    }];

    // SETUP TITLE LABEL
    CGSize titleSize = [self.issue.title sizeWithFont:titleFont constrainedToSize:CGSizeMake(170, MAXFLOAT) lineBreakMode:NSLineBreakByWordWrapping];
    uint titleLines = MIN(4, titleSize.height / textLineheight);

    titleLabel.frame = CGRectMake(ui.contentOffset, heightOffset, 170, textLineheight * titleLines);
    titleLabel.numberOfLines = titleLines;
    titleLabel.text = self.issue.title;

    heightOffset = heightOffset + titleLabel.frame.size.height + 5;

    // SETUP INFO LABEL
    CGSize infoSize = [self.issue.info sizeWithFont:infoFont constrainedToSize:CGSizeMake(170, MAXFLOAT) lineBreakMode:NSLineBreakByWordWrapping];
    uint infoLines = MIN(4, infoSize.height / textLineheight);

    infoLabel.frame = CGRectMake(ui.contentOffset, heightOffset, 170, textLineheight * infoLines);
    infoLabel.numberOfLines = infoLines;
    infoLabel.text = self.issue.info;

    heightOffset = heightOffset + infoLabel.frame.size.height + 5;

    // SETUP PRICE LABEL
    self.priceLabel.frame = CGRectMake(ui.contentOffset, heightOffset, 170, textLineheight);

    heightOffset = heightOffset + priceLabel.frame.size.height + 10;

    // SETUP ACTION BUTTON
    NSString *status = [self.issue getStatus];
    if ([status isEqualToString:@"remote"] || [status isEqualToString:@"purchasable"] || [status isEqualToString:@"purchased"]) {
        actionButton.frame = CGRectMake(ui.contentOffset, heightOffset, 110, 30);
    } else if ([status isEqualToString:@"downloaded"] || [status isEqualToString:@"bundled"]) {
        actionButton.frame = CGRectMake(ui.contentOffset, heightOffset, 80, 30);
    }

    // SETUP ARCHIVE BUTTON
    archiveButton.frame = CGRectMake(ui.contentOffset + 80 + 10, heightOffset, 80, 30);

    // SETUP DOWN/LOADING SPINNER AND LABEL
    spinner.frame = CGRectMake(ui.contentOffset, heightOffset, 30, 30);
    self.loadingLabel.frame = CGRectMake(ui.contentOffset + self.spinner.frame.size.width + 10, heightOffset, 135, 30);

    heightOffset = heightOffset + self.loadingLabel.frame.size.height + 5;

    // SETUP PROGRESS BAR
    self.progressBar.frame = CGRectMake(ui.contentOffset, heightOffset, 170, 30);
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self refresh];
}
- (void)refresh
{
    [self refresh:[self.issue getStatus]];
}
- (void)refresh:(NSString *)status
{
    NSLog(@"Refreshing %@ view with status %@ -> %@", self.issue.ID, currentStatus, status);
    if ([status isEqualToString:@"remote"])
    {
        [self.priceLabel setText:NSLocalizedString(@"FREE_TEXT", nil)];

        [self.actionButton setTitle:NSLocalizedString(@"ACTION_REMOTE_TEXT", nil) forState:UIControlStateNormal];
        [self.spinner stopAnimating];

        self.actionButton.hidden = NO;
        self.archiveButton.hidden = YES;
        self.progressBar.hidden = YES;
        self.loadingLabel.hidden = YES;
        self.priceLabel.hidden = NO;
    }
    else if ([status isEqualToString:@"connecting"])
    {
        [self.spinner startAnimating];

        self.actionButton.hidden = YES;
        self.archiveButton.hidden = YES;
        self.progressBar.progress = 0;
        self.loadingLabel.text = NSLocalizedString(@"CONNECTING_TEXT", nil);
        self.loadingLabel.hidden = NO;
        self.progressBar.hidden = YES;
        self.priceLabel.hidden = YES;
    }
    else if ([status isEqualToString:@"downloading"])
    {
        [self.spinner startAnimating];

        self.actionButton.hidden = YES;
        self.archiveButton.hidden = YES;
        self.progressBar.progress = 0;
        self.loadingLabel.text = NSLocalizedString(@"DOWNLOADING_TEXT", nil);
        self.loadingLabel.hidden = NO;
        self.progressBar.hidden = NO;
        self.priceLabel.hidden = YES;
    }
    else if ([status isEqualToString:@"downloaded"])
    {
        [self.actionButton setTitle:NSLocalizedString(@"ACTION_DOWNLOADED_TEXT", nil) forState:UIControlStateNormal];
        [self.spinner stopAnimating];

        self.actionButton.hidden = NO;
        self.archiveButton.hidden = NO;
        self.loadingLabel.hidden = YES;
        self.progressBar.hidden = YES;
        self.priceLabel.hidden = YES;
    }
    else if ([status isEqualToString:@"bundled"])
    {
        [self.actionButton setTitle:NSLocalizedString(@"ACTION_DOWNLOADED_TEXT", nil) forState:UIControlStateNormal];
        [self.spinner stopAnimating];

        self.actionButton.hidden = NO;
        self.archiveButton.hidden = YES;
        self.loadingLabel.hidden = YES;
        self.progressBar.hidden = YES;
        self.priceLabel.hidden = YES;
    }
    else if ([status isEqualToString:@"opening"])
    {
        [self.spinner startAnimating];

        self.actionButton.hidden = YES;
        self.archiveButton.hidden = YES;
        self.loadingLabel.text = NSLocalizedString(@"OPENING_TEXT", nil);
        self.loadingLabel.hidden = NO;
        self.progressBar.hidden = YES;
        self.priceLabel.hidden = YES;
    }
    else if ([status isEqualToString:@"purchasable"])
    {
        [self.actionButton setTitle:NSLocalizedString(@"ACTION_BUY_TEXT", nil) forState:UIControlStateNormal];
        [self.spinner stopAnimating];

        if (self.issue.price) {
            [self.priceLabel setText:self.issue.price];
        }

        self.actionButton.hidden = NO;
        self.archiveButton.hidden = YES;
        self.progressBar.hidden = YES;
        self.loadingLabel.hidden = YES;
        self.priceLabel.hidden = NO;
    }
    else if ([status isEqualToString:@"purchasing"])
    {
        [self.spinner startAnimating];

        self.loadingLabel.text = NSLocalizedString(@"BUYING_TEXT", nil);

        self.actionButton.hidden = YES;
        self.archiveButton.hidden = YES;
        self.progressBar.hidden = YES;
        self.loadingLabel.hidden = NO;
        self.priceLabel.hidden = NO;
    }
    else if ([status isEqualToString:@"purchased"])
    {
        [self.priceLabel setText:NSLocalizedString(@"PURCHASED_TEXT", nil)];

        [self.actionButton setTitle:NSLocalizedString(@"ACTION_REMOTE_TEXT", nil) forState:UIControlStateNormal];
        [self.spinner stopAnimating];

        self.actionButton.hidden = NO;
        self.archiveButton.hidden = YES;
        self.progressBar.hidden = YES;
        self.loadingLabel.hidden = YES;
        self.priceLabel.hidden = NO;
    }
    else if ([status isEqualToString:@"unpriced"])
    {
        [self.spinner startAnimating];

        self.loadingLabel.text = NSLocalizedString(@"RETRIEVING_TEXT", nil);

        self.actionButton.hidden = YES;
        self.archiveButton.hidden = YES;
        self.progressBar.hidden = YES;
        self.loadingLabel.hidden = NO;
        self.priceLabel.hidden = YES;
    }

    [self refreshContentWithCache:YES];

    currentStatus = status;
}

#pragma mark - Memory management

- (void)dealloc
{
    [issue release];
    [actionButton release];
    [archiveButton release];
    [progressBar release];
    [spinner release];
    [loadingLabel release];
    [priceLabel release];
    [issueCover release];
    [titleFont release];
    [infoFont release];
    [titleLabel release];
    [infoLabel release];

    [super dealloc];
}

#pragma mark - Issue management

- (void)actionButtonPressed:(UIButton *)sender
{
    NSString *status = [self.issue getStatus];
    if ([status isEqualToString:@"remote"] || [status isEqualToString:@"purchased"]) {
    #ifdef BAKER_NEWSSTAND
        [self download];
    #endif
    } else if ([status isEqualToString:@"downloaded"] || [status isEqualToString:@"bundled"]) {
        [self read];
    } else if ([status isEqualToString:@"downloading"]) {
        // TODO: assuming it is supported by NewsstandKit, implement a "Cancel" operation
    } else if ([status isEqualToString:@"purchasable"]) {
    #ifdef BAKER_NEWSSTAND
        [self buy];
    #endif
    }
}
#ifdef BAKER_NEWSSTAND
- (void)download {
    [self.issue download];
}
- (void)buy {
    [self addPurchaseObserver:@selector(handleIssuePurchased:) name:@"notification_issue_purchased"];
    [self addPurchaseObserver:@selector(handleIssuePurchaseFailed:) name:@"notification_issue_purchase_failed"];

    if (![purchasesManager purchase:self.issue.productID]) {
        // Still retrieving SKProduct: delay purchase
        purchaseDelayed = YES;

        [self removePurchaseObserver:@"notification_issue_purchased"];
        [self removePurchaseObserver:@"notification_issue_purchase_failed"];

        [purchasesManager retrievePriceFor:self.issue.productID];

        self.issue.transientStatus = BakerIssueTransientStatusUnpriced;
        [self refresh];
    } else {
        self.issue.transientStatus = BakerIssueTransientStatusPurchasing;
        [self refresh];
    }
}
- (void)handleIssuePurchased:(NSNotification *)notification {
    SKPaymentTransaction *transaction = [notification.userInfo objectForKey:@"transaction"];

    if ([transaction.payment.productIdentifier isEqualToString:issue.productID]) {

        [self removePurchaseObserver:@"notification_issue_purchased"];
        [self removePurchaseObserver:@"notification_issue_purchase_failed"];

        [purchasesManager markAsPurchased:transaction.payment.productIdentifier];

        if ([purchasesManager finishTransaction:transaction]) {
            if (!transaction.originalTransaction) {
                // Do not show alert on restoring a transaction
                [Utils showAlertWithTitle:NSLocalizedString(@"ISSUE_PURCHASE_SUCCESSFUL_TITLE", nil)
                                  message:[NSString stringWithFormat:NSLocalizedString(@"ISSUE_PURCHASE_SUCCESSFUL_MESSAGE", nil), self.issue.title]
                              buttonTitle:NSLocalizedString(@"ISSUE_PURCHASE_SUCCESSFUL_CLOSE", nil)];
            }
        } else {
            [Utils showAlertWithTitle:NSLocalizedString(@"TRANSACTION_RECORDING_FAILED_TITLE", nil)
                              message:NSLocalizedString(@"TRANSACTION_RECORDING_FAILED_MESSAGE", nil)
                          buttonTitle:NSLocalizedString(@"TRANSACTION_RECORDING_FAILED_CLOSE", nil)];
        }

        self.issue.transientStatus = BakerIssueTransientStatusNone;
        [purchasesManager retrievePurchasesFor:[NSSet setWithObject:self.issue.productID]];
        [self refresh];
    }
}
- (void)handleIssuePurchaseFailed:(NSNotification *)notification {
    SKPaymentTransaction *transaction = [notification.userInfo objectForKey:@"transaction"];

    if ([transaction.payment.productIdentifier isEqualToString:issue.productID]) {
        // Show an error, unless it was the user who cancelled the transaction
        if (transaction.error.code != SKErrorPaymentCancelled) {
            [Utils showAlertWithTitle:NSLocalizedString(@"ISSUE_PURCHASE_FAILED_TITLE", nil)
                              message:[transaction.error localizedDescription]
                          buttonTitle:NSLocalizedString(@"ISSUE_PURCHASE_FAILED_CLOSE", nil)];
        }

        [self removePurchaseObserver:@"notification_issue_purchased"];
        [self removePurchaseObserver:@"notification_issue_purchase_failed"];

        self.issue.transientStatus = BakerIssueTransientStatusNone;
        [self refresh];
    }
}

- (void)handleIssueRestored:(NSNotification *)notification {
    SKPaymentTransaction *transaction = [notification.userInfo objectForKey:@"transaction"];

    if ([transaction.payment.productIdentifier isEqualToString:issue.productID]) {
        [purchasesManager markAsPurchased:transaction.payment.productIdentifier];

        if (![purchasesManager finishTransaction:transaction]) {
            NSLog(@"Could not confirm purchase restore with remote server for %@", transaction.payment.productIdentifier);
        }

        self.issue.transientStatus = BakerIssueTransientStatusNone;
        [self refresh];
    }
}

- (void)setPrice:(NSString *)price {
    self.issue.price = price;
    if (purchaseDelayed) {
        purchaseDelayed = NO;
        [self buy];
    } else {
        [self refresh];
    }
}
#endif
- (void)read
{
    self.issue.transientStatus = BakerIssueTransientStatusOpening;
    [self refresh];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"read_issue_request" object:self];
}

#pragma mark - Newsstand download management

- (void)handleDownloadStarted:(NSNotification *)notification {
    [self refresh];
}
- (void)handleDownloadProgressing:(NSNotification *)notification {
    float bytesWritten = [[notification.userInfo objectForKey:@"totalBytesWritten"] floatValue];
    float bytesExpected = [[notification.userInfo objectForKey:@"expectedTotalBytes"] floatValue];

    if ([currentStatus isEqualToString:@"connecting"]) {
        self.issue.transientStatus = BakerIssueTransientStatusDownloading;
        [self refresh];
    }
    [self.progressBar setProgress:(bytesWritten / bytesExpected) animated:YES];
}
- (void)handleDownloadFinished:(NSNotification *)notification {
    self.issue.transientStatus = BakerIssueTransientStatusNone;
    [self refresh];
}
- (void)handleDownloadError:(NSNotification *)notification {
    [Utils showAlertWithTitle:NSLocalizedString(@"DOWNLOAD_FAILED_TITLE", nil)
                      message:NSLocalizedString(@"DOWNLOAD_FAILED_MESSAGE", nil)
                  buttonTitle:NSLocalizedString(@"DOWNLOAD_FAILED_CLOSE", nil)];

    self.issue.transientStatus = BakerIssueTransientStatusNone;
    [self refresh];
}

#pragma mark - Newsstand archive management

#ifdef BAKER_NEWSSTAND
- (void)archiveButtonPressed:(UIButton *)sender
{
    UIAlertView *updateAlert = [[UIAlertView alloc]
                                initWithTitle: NSLocalizedString(@"ARCHIVE_ALERT_TITLE", nil)
                                message: NSLocalizedString(@"ARCHIVE_ALERT_MESSAGE", nil)
                                delegate: self
                                cancelButtonTitle: NSLocalizedString(@"ARCHIVE_ALERT_BUTTON_CANCEL", nil)
                                otherButtonTitles: NSLocalizedString(@"ARCHIVE_ALERT_BUTTON_OK", nil), nil];
    [updateAlert show];
    [updateAlert release];
}

- (void) alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if(buttonIndex == 1){
        NKLibrary *nkLib = [NKLibrary sharedLibrary];
        NKIssue *nkIssue = [nkLib issueWithName:self.issue.ID];
        NSString *name = nkIssue.name;
        NSDate *date = nkIssue.date;
        
        [nkLib removeIssue:nkIssue];
        
        nkIssue = [nkLib addIssueWithName:name date:date];
        self.issue.path = [[nkIssue contentURL] path];
        
        [self refresh];
    }
}
#endif

#pragma mark - Helper methods

- (void)addPurchaseObserver:(SEL)notificationSelector name:(NSString *)notificationName {
    #ifdef BAKER_NEWSSTAND
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:notificationSelector
                                                 name:notificationName
                                               object:purchasesManager];
    #endif
}

- (void)removePurchaseObserver:(NSString *)notificationName {
    #ifdef BAKER_NEWSSTAND
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:notificationName
                                                  object:purchasesManager];
    #endif
}

- (void)addIssueObserver:(SEL)notificationSelector name:(NSString *)notificationName {
    #ifdef BAKER_NEWSSTAND
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:notificationSelector
                                                 name:notificationName
                                               object:nil];
    #endif
}

+ (UI)getIssueContentMeasures
{
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        UI iPad = {
            .cellPadding   = 30,
            .thumbWidth    = 135,
            .thumbHeight   = 180,
            .contentOffset = 184
        };
        return iPad;
    } else {
        UI iPhone = {
            .cellPadding   = 22,
            .thumbWidth    = 87,
            .thumbHeight   = 116,
            .contentOffset = 128
        };
        return iPhone;
    }
}

+ (int)getIssueCellHeight
{
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        return 240;
    } else {
        return 156;
    }
}
+ (CGSize)getIssueCellSize
{
    CGRect screenRect = [[UIScreen mainScreen] bounds];
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        return CGSizeMake((screenRect.size.width - 10) / 2, [IssueViewController getIssueCellHeight]);
    } else {
        return CGSizeMake(screenRect.size.width - 10, [IssueViewController getIssueCellHeight]);
    }
}

@end
