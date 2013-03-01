#import "GHAccount.h"
#import "GHApiClient.h"
#import "GHUser.h"
#import "GHGists.h"
#import "GHEvents.h"
#import "GHRepositories.h"
#import "GHOrganization.h"
#import "GHOrganizations.h"
#import "GHNotifications.h"
#import "iOctocat.h"
#import "NSString+Extensions.h"
#import "NSDictionary+Extensions.h"
#import "AFOAuth2Client.h"


@implementation GHAccount

static NSString *const LoginKeyPath = @"login";
static NSString *const OrgsLoadingKeyPath = @"organizations.resourceStatus";

- (id)initWithDict:(NSDictionary *)dict {
	self = [super init];
	if (self) {
		self.login = [dict safeStringForKey:kLoginDefaultsKey];
		self.endpoint = [dict safeStringForKey:kEndpointDefaultsKey];
		self.authToken = [dict safeStringForKey:kAuthTokenDefaultsKey];
		// construct endpoint URL and set up API client
		NSURL *apiURL = [NSURL URLWithString:kGitHubApiURL];
		if (!self.endpoint.isEmpty) {
			apiURL = [[NSURL URLWithString:self.endpoint] URLByAppendingPathComponent:kEnterpriseApiPath];
		}
		self.apiClient = [[GHApiClient alloc] initWithBaseURL:apiURL];
		[self.apiClient setAuthorizationHeaderWithToken:self.authToken];
		// user with authenticated URLs
		NSString *receivedEventsPath = [NSString stringWithFormat:kUserAuthenticatedReceivedEventsFormat, self.login];
		NSString *eventsPath = [NSString stringWithFormat:kUserAuthenticatedEventsFormat, self.login];
		self.user = [[iOctocat sharedInstance] userWithLogin:self.login];
		self.user.resourcePath = kUserAuthenticatedFormat;
		self.user.repositories.resourcePath = kUserAuthenticatedReposFormat;
		self.user.organizations.resourcePath = kUserAuthenticatedOrgsFormat;
		self.user.gists.resourcePath = kUserAuthenticatedGistsFormat;
		self.user.starredGists.resourcePath = kUserAuthenticatedGistsStarredFormat;
		self.user.starredRepositories.resourcePath = kUserAuthenticatedStarredReposFormat;
		self.user.watchedRepositories.resourcePath = kUserAuthenticatedWatchedReposFormat;
		self.user.notifications = [[GHNotifications alloc] initWithPath:kNotificationsFormat];
		self.user.receivedEvents = [[GHEvents alloc] initWithPath:receivedEventsPath account:self];
		self.user.events = [[GHEvents alloc] initWithPath:eventsPath account:self];
		[self.user addObserver:self forKeyPath:LoginKeyPath options:NSKeyValueObservingOptionNew context:nil];
		[self.user addObserver:self forKeyPath:OrgsLoadingKeyPath options:NSKeyValueObservingOptionNew context:nil];
	}
	return self;
}

- (void)dealloc {
	[self.user removeObserver:self forKeyPath:OrgsLoadingKeyPath];
	[self.user removeObserver:self forKeyPath:LoginKeyPath];
}

- (void)updateUserResourcePaths {
	self.user.receivedEvents.resourcePath = [NSString stringWithFormat:kUserAuthenticatedReceivedEventsFormat, self.user.login];
	self.user.events.resourcePath = [NSString stringWithFormat:kUserAuthenticatedEventsFormat, self.user.login];
	for (GHOrganization *org in self.user.organizations.items) {
		org.events.resourcePath = [NSString stringWithFormat:kUserAuthenticatedOrgEventsFormat, self.user.login, org.login];
	}
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
	if ([keyPath isEqualToString:LoginKeyPath] || ([keyPath isEqualToString:OrgsLoadingKeyPath] && self.user.organizations.isLoaded)) {
		[self updateUserResourcePaths];
	}
	if ([keyPath isEqualToString:LoginKeyPath]) {
		self.login = self.user.login;
	}
}

#pragma mark Coding

- (void)encodeWithCoder:(NSCoder *)encoder {
	[encoder encodeObject:self.login forKey:kLoginDefaultsKey];
	[encoder encodeObject:self.endpoint forKey:kEndpointDefaultsKey];
	[encoder encodeObject:self.authId forKey:kAuthIdDefaultsKey];
	[encoder encodeObject:self.authToken forKey:kAuthTokenDefaultsKey];
}

- (id)initWithCoder:(NSCoder *)decoder {
	NSString *login = [decoder decodeObjectForKey:kLoginDefaultsKey];
	NSString *endpoint = [decoder decodeObjectForKey:kEndpointDefaultsKey];
	NSString *authId = [decoder decodeObjectForKey:kAuthIdDefaultsKey];
	NSString *authToken = [decoder decodeObjectForKey:kAuthTokenDefaultsKey];
	self = [self initWithDict:@{
			kLoginDefaultsKey: login ? login : @"",
		 kEndpointDefaultsKey: endpoint ? endpoint : @"",
		   kAuthIdDefaultsKey: authId ? authId : @"",
		kAuthTokenDefaultsKey: authToken ? authToken : @""}];
	return self;
}

@end