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


- (BOOL)gistify:(NSDocument *)document
{
    id<MacDownMarkdownSource> markdownSource = (id)document;
    NSString *markdown = markdownSource.markdown;
    if (!markdown.length)
        return NO;
    NSString *fileName = document.fileURL.path.lastPathComponent;
    if (!fileName.length)
        fileName = @"Untitled";

    
    
    markdown = [[self blocksFrom: markdown] objectAtIndex: 0];
    
    
    
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
        @"files": @{fileName: @{@"content": markdown}},
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

        NSAlert *alert = [[NSAlert alloc] init];
        if (error)
        {
            alert = [NSAlert alertWithError:error];
        }
        else if (![res respondsToSelector:@selector(statusCode)])
        {
            alert.alertStyle = NSWarningAlertStyle;
            alert.messageText = @"Unknown error";
        }
        else if (r.statusCode != 201 || !urlstring)
        {
            alert.alertStyle = NSWarningAlertStyle;
            NSString *f = @"Unexpection return code %ld";
            alert.messageText = [NSString stringWithFormat:f, r.statusCode];
            if (json)
                alert.informativeText = json;
        }

        alert.alertStyle = NSInformationalAlertStyle;
        alert.messageText = @"Gist created";
        alert.informativeText = [NSString stringWithFormat:
            @"You gist is at %@\nThe URL has been copied into your clipboard.",
            urlstring];

        NSPasteboard *pb = [NSPasteboard generalPasteboard];
        [pb clearContents];
        [pb writeObjects:@[urlstring]];

        dispatch_async(dispatch_get_main_queue(), ^{
            [alert runModal];
        });
    }];
    [task resume];

    return YES;
}

@end
