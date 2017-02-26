#import <UIKit/UIKit.h>
#import <Cordova/CDVPlugin.h>
#include "curl.h"

@interface CDVCurl : CDVPlugin
{}

@property (nonatomic, copy) NSString* callbackId;

- (void)cookie:(CDVInvokedUrlCommand*)command;
- (void)setCookie:(CDVInvokedUrlCommand*)command;
- (void)reset:(CDVInvokedUrlCommand*)command;
- (void)query:(CDVInvokedUrlCommand*)command;

@end
