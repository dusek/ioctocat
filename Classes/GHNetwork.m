#import "GHNetwork.h"

@implementation GHNetwork

@synthesize description, name, url, user, repository;

- (void)dealloc {
    [description release];
    [name release];
    [url release];
    [user release];
    [super dealloc];
}

@end
