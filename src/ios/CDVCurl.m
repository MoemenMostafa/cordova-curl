#import <Cordova/CDV.h>
#import "CDVCurl.h"

struct MemoryStruct {
    char *memory;
    size_t size;
};

@interface CDVCurl () {}
@end

@implementation CDVCurl

- (void)reset:(CDVInvokedUrlCommand*)command
{
    NSString *cookieName;
    if ([[command argumentAtIndex:0] isKindOfClass:[NSString class]])
    cookieName = [command argumentAtIndex:0];
    else
    cookieName = @"cookie";
    CDVPluginResult* pluginResult;
    if (unlink([[[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject] stringByAppendingPathComponent:cookieName] UTF8String]))
    pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    else
    pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void)cookie:(CDVInvokedUrlCommand*)command
{
    NSString *cookieName;
    if ([[command argumentAtIndex:0] isKindOfClass:[NSString class]])
        cookieName = [command argumentAtIndex:0];
    else
        cookieName = @"cookie";
    NSError *error;
    NSString *data = [NSString stringWithContentsOfFile:[[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject] stringByAppendingPathComponent:cookieName] encoding:NSASCIIStringEncoding error:&error];
    CDVPluginResult* pluginResult;
    NSLog(@"%@", error);
    if (!error) pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:data];
    else pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}
    
- (void)setCookie:(CDVInvokedUrlCommand*)command
{
        NSString *cookieName;
        if ([[command argumentAtIndex:0] isKindOfClass:[NSString class]])
            cookieName = [command argumentAtIndex:0];
        else
            cookieName = @"cookie";
        NSString *cookie = [command argumentAtIndex:1];
        NSError *error;

        [cookie writeToFile:[[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject] stringByAppendingPathComponent:cookieName] atomically:NO encoding:NSASCIIStringEncoding error:&error];

        CDVPluginResult* pluginResult;
        NSLog(@"%@ %@", error, [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject] stringByAppendingPathComponent:cookieName]);

        if (!error)
            pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
        else
            pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR];

        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void)query:(CDVInvokedUrlCommand*)command
{
    NSString *url = [command argumentAtIndex:0];
    NSArray *headers = [command argumentAtIndex:1];
    NSData *postfields_data = NULL;
    NSString *postfields_string = NULL;
    
    if ([[command argumentAtIndex:2] isKindOfClass:[NSString class]])
        postfields_string = [command argumentAtIndex:2];
    else
        postfields_data = [command argumentAtIndex:2];
    
    NSNumber *follow = [command argumentAtIndex:3];
    
    NSString *cookieName;
    
    if ([[command argumentAtIndex:4] isKindOfClass:[NSString class]])
        cookieName = [command argumentAtIndex:4];
    else
        cookieName = @"cookie";
    
    NSString *callbackId = command.callbackId;
    [self.commandDelegate runInBackground:^{
        CDVPluginResult* pluginResult;
        struct MemoryStruct chunk;
        chunk.memory = malloc(1);
        chunk.memory[0] = 0;
        chunk.size = 0;
        CURL *curl = curl_easy_init();
        if (curl) {
            curl_easy_setopt(curl, CURLOPT_URL, [url UTF8String]);
            //curl_easy_setopt(curl, CURLOPT_PROXY, "10.0.0.53");
            //curl_easy_setopt(curl, CURLOPT_PROXYPORT, 5555);
            NSString *cookie = [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject] stringByAppendingPathComponent:cookieName];
            curl_easy_setopt(curl, CURLOPT_COOKIEFILE, [cookie UTF8String]);
            curl_easy_setopt(curl, CURLOPT_COOKIEJAR, [cookie UTF8String]);
            curl_easy_setopt(curl, CURLOPT_WRITEFUNCTION, WriteMemoryCallback);
            curl_easy_setopt(curl, CURLOPT_WRITEDATA, (void *)&chunk);
            curl_easy_setopt(curl, CURLOPT_HEADER, 1);
            if ([[command argumentAtIndex:5] isKindOfClass:[NSString class]])
                curl_easy_setopt(curl, CURLOPT_CUSTOMREQUEST, [[command argumentAtIndex:5] UTF8String]);
            if ([follow boolValue]) curl_easy_setopt(curl, CURLOPT_FOLLOWLOCATION, 1);
            if (postfields_string != NULL) curl_easy_setopt(curl, CURLOPT_POSTFIELDS, [postfields_string UTF8String]);
            else if (postfields_data != NULL) curl_easy_setopt(curl, CURLOPT_POSTFIELDS, [postfields_data bytes]);
            struct curl_slist *list = NULL;
            for (NSString *header in headers) list = curl_slist_append(list, [header UTF8String]);
            curl_easy_setopt(curl, CURLOPT_HTTPHEADER, list);
            if (curl_easy_perform(curl) == CURLE_OK) {
                long header_size;
                curl_easy_getinfo(curl, CURLINFO_HEADER_SIZE, &header_size);
                NSString *data = [NSString stringWithCString:chunk.memory encoding:NSUTF8StringEncoding];
                pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsArray:@[[data substringFromIndex:header_size], [data substringToIndex:header_size]]];
            } else pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR];
            free(chunk.memory);
            curl_easy_cleanup(curl);
            curl_slist_free_all(list);
        } else pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:callbackId];
    }];
}

size_t WriteMemoryCallback(void *contents, size_t size, size_t nmemb, void *userp)
{
    size_t realsize = size * nmemb;
    struct MemoryStruct *mem = (struct MemoryStruct *)userp;
    mem->memory = realloc(mem->memory, mem->size + realsize + 1);
    if (mem->memory == NULL) return 0;
    memcpy(&(mem->memory[mem->size]), contents, realsize);
    mem->size += realsize;
    mem->memory[mem->size] = 0;
    return realsize;
}

@end
