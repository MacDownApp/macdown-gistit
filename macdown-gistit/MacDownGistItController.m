//
//  MacDownGistItController.m
//  macdown-gistit
//
//  Created by Tzu-ping Chung on 08/3.
//  Copyright © 2016 uranusjr. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "MacDownGistItController.h"


static NSString * const MacDownGistListLink = @"https://api.github.com/gists";


@protocol MacDownMarkdownSource <NSObject>

@property (readonly) NSString *markdown;

@end


@implementation MacDownGistItController

- (NSString *)name
{
    return @"Gist It!";
}

- (BOOL)run:(id)sender
{
    NSDocumentController *dc = [NSDocumentController sharedDocumentController];
    return [self gistify:dc.currentDocument];
}


- (NSArray *) blocksFrom: (NSString *) text {
  
    NSString * str = text;
    NSMutableArray * result = [NSMutableArray array];
    
    while (true) {
        NSRange range = [str rangeOfString: @"```"];
        
        if (range.length > 0) {
            str = [NSString stringWithString: [str substringFromIndex: range.location + range.length]];
            
            NSRange codeRange = [str rangeOfString: @"```"];
            
            NSString * code = [str substringToIndex:codeRange.location];
            
            [result addObject: code];
            
            str = [NSString stringWithString: [str substringFromIndex: codeRange.location + codeRange.length]];
        }
        else break;
    }
    
    return result;
    
}


- (BOOL) gistify:(NSDocument *)document
{
    id<MacDownMarkdownSource> markdownSource = (id)document;
    NSString *markdown = markdownSource.markdown;
    if (!markdown.length)
        return NO;
    NSString *fileName = document.fileURL.path.lastPathComponent;
    if (!fileName.length)
        fileName = @"Untitled";

    
    
    NSArray * blocks = [self blocksFrom: markdown];
    
    __block NSString * result = @"Your Gists urls:\n";

    __block int m = 0;
    
    for (NSString * block in blocks) {
        
        NSURL * url = [NSURL URLWithString:MacDownGistListLink];
        NSMutableURLRequest *req =
        [NSMutableURLRequest requestWithURL:url
                                cachePolicy:NSURLRequestReloadIgnoringCacheData
                            timeoutInterval:0.0];
        [req addValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
        [req addValue:@"application/json" forHTTPHeaderField:@"Accept"];
        
        NSDictionary *object = @{
                                 @"description": @"Uploaded by MacDown. http://macdown.uranusjr.com",
                                 @"public": @YES,
                                 @"files": @{fileName: @{@"content": block}},
                                 };
        NSData *data = [NSJSONSerialization dataWithJSONObject:object
                                                       options:0 error:NULL];
        
        if (!data)
            return NO;
        
        req.HTTPMethod = @"POST";
        req.HTTPBody = data;
        
        NSURLSessionConfiguration *conf =
        [NSURLSessionConfiguration defaultSessionConfiguration];
        NSURLSession *session = [NSURLSession sessionWithConfiguration:conf];
        NSURLSessionTask *task = [session dataTaskWithRequest:req
                                            completionHandler:^(
                                                                NSData *data, NSURLResponse *res, NSError *error) {
                                                
                                                NSHTTPURLResponse *r = (id)res;
                                                NSString *json = data ?
                                                [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] :
                                                nil;
                                                NSDictionary *object = data ?
                                                [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL] :
                                                nil;
                                                NSString *urlstring = object[@"html_url"];
                                                
                                                
                                                result = [result stringByAppendingString: [@"\n" stringByAppendingString: urlstring]];
                                                m = m + 1;
                                            }];
        [task resume];
    }
    
    while (m < blocks.count) {}

    
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = result;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [alert runModal];
    });
    
    return YES;
}

@end
