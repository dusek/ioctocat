#import "EventsController.h"
#import "GHEvent.h"
#import "GHEvents.h"
#import "IOCUserController.h"
#import "IOCRepositoryController.h"
#import "IOCIssueController.h"
#import "IOCPullRequestController.h"
#import "IOCCommitController.h"
#import "IOCGistController.h"
#import "WebController.h"
#import "IOCCommitsController.h"
#import "IOCOrganizationController.h"
#import "GHUser.h"
#import "GHOrganization.h"
#import "GHRepository.h"
#import "GHIssue.h"
#import "GHCommit.h"
#import "GHCommits.h"
#import "GHGist.h"
#import "GHPullRequest.h"
#import "iOctocat.h"
#import "EventCell.h"
#import "NSDate+Nibware.h"
#import "NSDictionary+Extensions.h"
#import "UIScrollView+SVPullToRefresh.h"
#import "IOCViewControllerFactory.h"

#define kEventCellIdentifier @"EventCell"


@interface EventsController () <EventCellDelegate>
@property(nonatomic,strong)GHEvents *events;
@property(nonatomic,strong)IBOutlet UITableViewCell *noEntriesCell;
@property(nonatomic,strong)IBOutlet EventCell *eventCell;
@end


@implementation EventsController

- (id)initWithEvents:(GHEvents *)events {
	self = [super initWithNibName:@"Events" bundle:nil];
	if (self) {
		self.events = events;
	}
	return self;
}

#pragma mark View Events

- (void)viewDidLoad {
	[super viewDidLoad];
	self.clearsSelectionOnViewWillAppear = NO;
	[self setupPullToRefresh];
	[self refreshLastUpdate];
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(refreshIfRequired) name:UIApplicationDidBecomeActiveNotification object:nil];
}

- (void)viewDidAppear:(BOOL)animated {
	[super viewDidAppear:animated];
	[self refreshLastUpdate];
	[self refreshIfRequired];
}

- (void)viewWillDisappear:(BOOL)animated {
	[super viewWillDisappear:animated];
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark Actions

- (void)openEventItemWithGitHubURL:(NSURL *)url {
    UIViewController *viewController = [IOCViewControllerFactory viewControllerForGitHubURL:url];
    if (viewController) [self.navigationController pushViewController:viewController animated:YES];
}

#pragma mark TableView

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	return self.events.isLoaded && self.events.isEmpty ? 1 : self.events.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	if (self.events.isEmpty) return self.noEntriesCell;
	EventCell *cell = (EventCell *)[tableView dequeueReusableCellWithIdentifier:kEventCellIdentifier];
	if (cell == nil) {
		[[NSBundle mainBundle] loadNibNamed:@"EventCell" owner:self options:nil];
		cell = _eventCell;
		cell.delegate = self;
	}
	GHEvent *event = self.events[indexPath.row];
	cell.event = event;
	(event.read) ? [cell markAsRead] : [cell markAsNew];
	return cell;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
	return [(EventCell *)[self tableView:tableView cellForRowAtIndexPath:indexPath] heightForTableView:tableView];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	if (self.events.isEmpty) return;
	[self.tableView beginUpdates];
	[(EventCell *)[self tableView:tableView cellForRowAtIndexPath:indexPath] markAsRead];
	[self.tableView endUpdates];
}

#pragma mark Helpers

- (void)setupPullToRefresh {
	__weak __typeof(&*self)weakSelf = self;
	[self.tableView addPullToRefreshWithActionHandler:^{
        if (weakSelf.events.isLoading) {
            dispatch_async(dispatch_get_main_queue(),^ {
                [weakSelf.tableView.pullToRefreshView performSelector:@selector(stopAnimating) withObject:nil afterDelay:.25];
            });
        } else {
            [weakSelf.events loadWithParams:nil start:nil success:^(GHResource *instance, id data) {
                dispatch_async(dispatch_get_main_queue(),^ {
                    [weakSelf refreshLastUpdate];
                    [weakSelf.tableView reloadData];
                    [weakSelf.tableView.pullToRefreshView performSelector:@selector(stopAnimating) withObject:nil afterDelay:.25];
                });
            } failure:^(GHResource *instance, NSError *error) {
                dispatch_async(dispatch_get_main_queue(),^ {
                    [weakSelf.tableView.pullToRefreshView performSelector:@selector(stopAnimating) withObject:nil afterDelay:.25];
                    [iOctocat reportLoadingError:@"Could not load the feed"];
                });
            }];
        }
	}];
	[self refreshLastUpdate];
}

- (void)refreshLastUpdate {
	if (self.events.lastUpdate) {
		NSString *lastRefresh = [NSString stringWithFormat:@"Last refresh %@", [self.events.lastUpdate prettyDate]];
		[self.tableView.pullToRefreshView setSubtitle:lastRefresh forState:SVPullToRefreshStateAll];
	}
}

- (void)refreshIfRequired {
    if (self.events.isLoading) return;
    NSDate *lastActivatedDate = [[NSUserDefaults standardUserDefaults] objectForKey:kLastActivatedDateDefaultsKey];
    if (!self.events.isLoaded || [self.events.lastUpdate compare:lastActivatedDate] == NSOrderedAscending) {
        // the feed was loaded before this application became active again, refresh it
        [self.tableView triggerPullToRefresh];
    }
}

@end