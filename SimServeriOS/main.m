//
//  main.m
//  SimServeriOS
//
//  Created by Zhuowei Zhang on 2022-07-03.
//

#import <UIKit/UIKit.h>
#import "AppDelegate.h"
#import <GCDWebServer/GCDWebServer.h>
#import <GCDWebServer/GCDWebServerDataResponse.h>
@import CoreTelephony;

@interface CTSubscriberAuthDataHolder: NSObject
- (instancetype)initWithData:(NSDictionary<NSString*, id>*)data;
@end

@interface CTXPCServiceSubscriptionContext: NSObject
@end

@interface CTXPCServiceSubscriptionInfo: NSObject
@property (readonly, nonatomic) NSArray<CTXPCServiceSubscriptionContext*>* subscriptions;
@end

@interface CoreTelephonyClient: NSObject
- (CTXPCServiceSubscriptionInfo*)getSubscriptionInfoWithError:(NSError**)error;
- (NSString*)copyMobileSubscriberIdentity:(CTXPCServiceSubscriptionContext*)subscriptionContext error:(NSError**)error;
- (void)generateAuthenticationInfoUsingSim:(CTXPCServiceSubscriptionContext*)subscriptionContext authParams:(CTSubscriberAuthDataHolder*)authParams completion:(void (^)(CTSubscriberAuthDataHolder *authInfo, NSError *error))completion;
@end

static void CreateAuthResponse(void (^completion)(NSDictionary<NSString*, id>* response, NSError* error)) {
    // https://github.com/apple-oss-distributions/eap8021x/blob/4dee95a5037b6330a6539cc53a79f176fc084b26/EAP8021X.fproj/SIMAccess.m#L387
    NSError* error = nil;
    CoreTelephonyClient *coreTelephonyclient = [CoreTelephonyClient new];
    
    CTXPCServiceSubscriptionInfo* subscriptionInfo = [coreTelephonyclient getSubscriptionInfoWithError:&error];
    if (error) {
        completion(nil, error);
        return;
    }
    CTXPCServiceSubscriptionContext* preferredSubscriptionCtx = subscriptionInfo.subscriptions[0];
    CTSubscriberAuthDataHolder* authInputParams = [[CTSubscriberAuthDataHolder alloc] initWithData:@{}];
    [coreTelephonyclient generateAuthenticationInfoUsingSim:preferredSubscriptionCtx
                                                 authParams:authInputParams completion:^(CTSubscriberAuthDataHolder *authInfo, NSError *error) {
    }];
    completion(nil, [NSError errorWithDomain:@"com.worthdoingbadly.SimServeriOS" code:1234 userInfo:nil]);
}

static void StartServer(void) {
    static GCDWebServer* webServer;
    webServer = [GCDWebServer new];
    [webServer addDefaultHandlerForMethod:@"GET" requestClass:[GCDWebServerRequest class] asyncProcessBlock:^(GCDWebServerRequest* request, GCDWebServerCompletionBlock completionBlock) {
        NSDictionary<NSString*, id>* responseDict = nil;
        responseDict = @{
            @"err": @"invalid command",
        };
        completionBlock([GCDWebServerDataResponse responseWithJSONObject:responseDict]);
    }];
}

static void PrintImsi(void) {
    NSError* error = nil;
    CoreTelephonyClient *coreTelephonyclient = [CoreTelephonyClient new];
    
    CTXPCServiceSubscriptionInfo* subscriptionInfo = [coreTelephonyclient getSubscriptionInfoWithError:&error];
    if (error) {
        NSLog(@"%@", error);
        return;
    }
    CTXPCServiceSubscriptionContext* preferredSubscriptionCtx = subscriptionInfo.subscriptions[0];
    NSString* imsi = [coreTelephonyclient copyMobileSubscriberIdentity:preferredSubscriptionCtx error:&error];
    if (error) {
        NSLog(@"%@", error);
        return;
    }
    printf("%s\n", imsi.UTF8String);
}

static void PerformAuthBase64(char* base64String) {
}

int main(int argc, char** argv) {
    if (argc < 2) {
        fprintf(stderr, "usage:\n"
                "imsi: prints imsi\n"
                "auth <base64-encoded data>: authenticates with EAP_AKA on ISIM\n"
                "serve <port>: serves web server\n");
        PrintImsi();
        return 0;
    }
    if (!strcmp(argv[1], "imsi")) {
        PrintImsi();
    } else if (!strcmp(argv[1], "auth")) {
        PerformAuthBase64(argv[2]);
    } else if (!strcmp(argv[1], "serve")) {
        StartServer();
    } else {
        fprintf(stderr, "wrong arg\n");
        return 1;
    }
    CFRunLoopRun();
    return 0;
}

#if 0
int main(int argc, char * argv[]) {
    NSString * appDelegateClassName;
    @autoreleasepool {
        // Setup code that might create autoreleased objects goes here.
        appDelegateClassName = NSStringFromClass([AppDelegate class]);
    }
    return UIApplicationMain(argc, argv, nil, appDelegateClassName);
}
#endif
