//
//  RCTRongCloud.m
//  RCTRongCloud
//
//  Created by LvBingru on 1/26/16.
//  Copyright © 2016 erica. All rights reserved.
//

#import "RCTRongCloud.h"
#import <RongIMLib/RongIMLib.h>
#import "RCTConvert+RongCloud.h"
#import "RCTUtils.h"
#import "RCTEventDispatcher.h"
#import "RCTRongCloudVoiceManager.h"

#define OPERATION_FAILED (@"operation returns false.")

@interface RCTRongCloud()<RCIMClientReceiveMessageDelegate>

@property (nonatomic, strong) NSMutableDictionary *userInfoDic;
@property (nonatomic, strong) RCTRongCloudVoiceManager *voiceManager;

@end

@implementation RCTRongCloud

RCT_EXPORT_MODULE(RCTRongIMLib);

@synthesize bridge = _bridge;

- (NSDictionary *)constantsToExport
{
    return @{};
};

- (dispatch_queue_t)methodQueue
{
    return dispatch_get_main_queue();
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        [[self shareClient] setReceiveMessageDelegate:self object:nil];
        _voiceManager = [RCTRongCloudVoiceManager new];
    }
    [[NSNotificationCenter defaultCenter] addObserver:RCLibDispatchReadReceiptNotification selector:@selector(dispatchReadReceiptNotification:) name:@"dispatchReadReceiptNotification" object:nil];
    
    return self;
}

- (void)dealloc
{
    [[self shareClient] disconnect];
    [[self shareClient] setReceiveMessageDelegate:nil object:nil];
}

+ (void)registerAPI:(NSString *)aString
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        [[RCIMClient sharedRCIMClient] initWithAppKey:aString];
    });
}

+ (void)setDeviceToken:(NSData *)aToken
{
    NSString *token =
    [[[[aToken description] stringByReplacingOccurrencesOfString:@"<"
                                                      withString:@""]
      stringByReplacingOccurrencesOfString:@">"
      withString:@""]
     stringByReplacingOccurrencesOfString:@" "
     withString:@""];
    
    [[RCIMClient sharedRCIMClient] setDeviceToken:token];
}

+ (void)dispatchReadReceiptNotification:(NSNotification *) notification
{
//    NSLog(@"%@", notification);
}

-(RCIMClient *) shareClient {
    return [RCIMClient sharedRCIMClient];
}

RCT_EXPORT_METHOD(connect:(NSString *)token resolve:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject)
{
    [[self shareClient] connectWithToken:token success:^(NSString *userId) {
        // Connect 成功
        resolve(userId);
    } error:^(RCConnectErrorCode status) {
        // Connect 失败
        reject([NSString stringWithFormat:@"%d", (int)status], @"Connection error", nil);
    }
                                     tokenIncorrect:^() {
                                         // Token 失效的状态处理
                                         reject(@"tokenIncorrect", @"Incorrect token provided.", nil);
                                     }];
}

RCT_EXPORT_METHOD(getConnectionStatus:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject)
{
    RCConnectionStatus status = [[self shareClient] getConnectionStatus];
    NSLog(@"status: %@", status);
    resolve(nil);
}

// 断开与融云服务器的连接，并不再接收远程推送
RCT_EXPORT_METHOD(logout:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject)
{
    [[self shareClient] logout];
    resolve(nil);
}

// 断开与融云服务器的连接，但仍然接收远程推送
RCT_EXPORT_METHOD(disconnect:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject)
{
    [[self shareClient] disconnect];
    resolve(nil);
}

RCT_EXPORT_METHOD(getTotalUnreadCount:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject)
{
    int totalUnreadCount = [[self shareClient] getTotalUnreadCount];
    resolve([NSString stringWithFormat:@"%d", totalUnreadCount]);
}

RCT_EXPORT_METHOD(getConversationList:(NSArray *)conversationTypeList resolve:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject)
{
    NSArray *array = [NSArray alloc];
    if ([conversationTypeList count] > 0) {
        NSArray * typeList = [self.class _convertConversationTypeArray: conversationTypeList];
        array = [[self shareClient] getConversationList:typeList];
    } else {
        array = [[self shareClient] getConversationList:@[@(ConversationType_PRIVATE),
                                                           @(ConversationType_DISCUSSION),
                                                           @(ConversationType_GROUP),
                                                           @(ConversationType_CHATROOM),
                                                           @(ConversationType_CUSTOMERSERVICE),
                                                           @(ConversationType_SYSTEM),
                                                           @(ConversationType_APPSERVICE),
                                                           @(ConversationType_PUBLICSERVICE),
                                                           @(ConversationType_PUSHSERVICE)]];
    }
    
    NSMutableArray *newArray = [NSMutableArray new];
    for (RCConversation *conv in array) {
        NSDictionary *convDic = [self.class _convertConversation:conv];
        [newArray addObject:convDic];
    }
    resolve(newArray);
}

RCT_EXPORT_METHOD(getConversation:(RCConversationType)conversationType targetId:(NSString *)targetId resolve:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject)
{
    RCConversation *conv = [[self shareClient] getConversation:conversationType targetId:targetId];
    resolve([self.class _convertConversation:conv]);
}

RCT_EXPORT_METHOD(sendReadReceiptMessage:(RCConversationType)conversationType targetId:(NSString *)targetId time:(nonnull NSNumber *)time)
{
    //NSLog(@"Long long timestamp %ld", time);
    [[self shareClient] sendReadReceiptMessage:conversationType targetId:targetId time:(long long)time];
}

RCT_EXPORT_METHOD(clearConversations: (NSArray *)conversationTypeList)
{
    [[self shareClient] clearConversations:conversationTypeList];
}

RCT_EXPORT_METHOD(removeConversation: (RCConversationType)conversationType  targetId:(NSString *)targetId)
{
    [[self shareClient] removeConversation:conversationType targetId:targetId];
}

RCT_EXPORT_METHOD(setMessageReceivedStatus:(long)messageId receivedStatus:(RCReceivedStatus)receivedStatus)
{
    [[self shareClient] setMessageReceivedStatus:messageId receivedStatus:receivedStatus];
}

RCT_EXPORT_METHOD(getLatestMessages: (RCConversationType) type targetId:(NSString*) targetId count:(int) count
                  resolve:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject)
{
    NSArray* array = [[self shareClient] getLatestMessages:type targetId:targetId count:count];
    
    NSMutableArray* newArray = [NSMutableArray new];
    for (RCMessage* msg in array) {
        NSLog(@"%@", msg);
        NSDictionary* convDic = [self.class _convertMessage:msg];
        [newArray addObject:convDic];
    }
    resolve(newArray);
}

RCT_EXPORT_METHOD(sendMessage: (RCConversationType) type targetId:(NSString*) targetId content:(RCMessageContent*) content
                  pushContent: (NSString*) pushContent pushData:(NSString*) pushData
                  resolve:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject)
{
    RCMessage* msg = [[self shareClient] sendMessage:type targetId:targetId content:content pushContent:pushContent
                success:^(long messageId){
                    [_bridge.eventDispatcher sendAppEventWithName:@"msgSendOk" body:@(messageId)];
                } error:^(RCErrorCode code, long messageId){
                    NSMutableDictionary* dic = [NSMutableDictionary new];
                    dic[@"messageId"] = @(messageId);
                    dic[@"errCode"] = @((int)code);
                    [_bridge.eventDispatcher sendAppEventWithName:@"msgSendFailed" body:dic];
                }];
    resolve([self.class _convertMessage:msg]);
}

RCT_EXPORT_METHOD(deleteMessages:(NSArray *)messageIds)
{
    [[self shareClient] deleteMessages:messageIds];
}

RCT_EXPORT_METHOD(clearMessagesUnreadStatus:(RCConversationType)conversationType targetId:(NSString *)targetId)
{
    [[self shareClient] clearMessagesUnreadStatus:conversationType targetId:targetId];
}

RCT_EXPORT_METHOD(canRecordVoice:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject)
{
    [_voiceManager canRecordVoice:^(NSError *error, NSDictionary *result) {
        if (error) {
            reject([NSString stringWithFormat:@"%ld", error.code], error.description, error);
        }
        else {
            resolve(result);
        }
    }];
}

RCT_EXPORT_METHOD(startRecordVoice:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject)
{
    [_voiceManager startRecord:^(NSError *error,NSDictionary *result) {
        if (error) {
            reject([NSString stringWithFormat:@"%ld", error.code], error.description, error);
        }
        else {
            resolve(result);
        }
    }];
}

RCT_EXPORT_METHOD(cancelRecordVoice)
{
    [_voiceManager cancelRecord];
}

RCT_EXPORT_METHOD(finishRecordVoice)
{
    [_voiceManager finishRecord];
}

RCT_EXPORT_METHOD(startPlayVoice:(RCMessageContent *)voice rosolve:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject)
{
    [_voiceManager startPlayVoice:(RCVoiceMessage *)voice result:^(NSError *error, NSDictionary *result) {
        if (error) {
            reject([NSString stringWithFormat:@"%ld", error.code], error.description, error);
        }
        else {
            resolve(result);
        }
    }];
}

RCT_EXPORT_METHOD(stopPlayVoice)
{
    [_voiceManager stopPlayVoice];
}

#pragma mark - delegate
- (void)onReceived:(RCMessage *)message
              left:(int)nLeft
            object:(id)object
{
    NSLog(@"onReceived : %@", [self.class _convertMessage:message]);
    [_bridge.eventDispatcher sendAppEventWithName:@"rongIMMsgRecved" body:[self.class _convertMessage:message]];
}

#pragma mark - private

+ (NSDictionary *)_convertConversation:(RCConversation *)conversation
{
    NSMutableDictionary *dic = [NSMutableDictionary new];
    dic[@"title"] = conversation.conversationTitle;
    dic[@"type"] = [self _converConversationType:conversation.conversationType];
    dic[@"targetId"] = conversation.targetId;
    dic[@"unreadCount"] = @(conversation.unreadMessageCount);
    dic[@"lastMessage"] = [self _converMessageContent:conversation.lastestMessage];
    
    dic[@"isTop"] = @(conversation.isTop);
    dic[@"receivedStatus"] = @(conversation.receivedStatus);
    dic[@"sentStatus"] = @(conversation.sentStatus);
    dic[@"receivedTime"] = @(conversation.receivedTime);
    dic[@"sentTime"] = @(conversation.sentTime);
    dic[@"draft"] = conversation.draft;
    dic[@"objectName"] = conversation.objectName;
    dic[@"senderUserId"] = conversation.senderUserId;
    //dic[@"jsonDict"] = conversation.jsonDict;
    dic[@"lastestMessageId"] = @(conversation.lastestMessageId);
    return dic;
}

+ (NSDictionary *)_convertMessage:(RCMessage *)message
{
    NSMutableDictionary *dic = [NSMutableDictionary new];
    dic[@"senderId"] = message.senderUserId;
    dic[@"targetId"] = message.targetId;
    dic[@"conversationType"] = @(message.conversationType);
    dic[@"extra"] = message.extra;
    dic[@"messageId"] = @(message.messageId);
    dic[@"receivedTime"] = @(message.receivedTime);
    dic[@"sentTime"] = @(message.sentTime);
    dic[@"content"] = [self _converMessageContent:message.content];

    dic[@"messageDirection"] = @(message.messageDirection);
    dic[@"receivedStatus"] = @(message.receivedStatus);
    dic[@"sentStatus"] = @(message.sentStatus);
    dic[@"objectName"] = message.objectName;
    dic[@"messageUId"] = message.messageUId;
    return dic;
}

+ (NSDictionary *)_converMessageContent:(RCMessageContent *)messageContent
{
    NSMutableDictionary *dic = [NSMutableDictionary new];
    if ([messageContent isKindOfClass:[RCTextMessage class]]) {
        RCTextMessage *message = (RCTextMessage *)messageContent;
        dic[@"type"] = @"text";
        dic[@"content"] = message.content;
        dic[@"extra"] = message.extra;
    }
    else if ([messageContent isKindOfClass:[RCVoiceMessage class]]) {
        RCVoiceMessage *message = (RCVoiceMessage *)messageContent;
        dic[@"type"] = @"voice";
        dic[@"duration"] = @(message.duration);
        dic[@"extra"] = message.extra;
        if (message.wavAudioData) {
            dic[@"base64"] = [message.wavAudioData base64EncodedStringWithOptions:(NSDataBase64EncodingOptions)0];
        }
    }
    else if ([messageContent isKindOfClass:[RCImageMessage class]]) {
        RCImageMessage *message = (RCImageMessage*)messageContent;
        dic[@"type"] = @"image";
        dic[@"imageUrl"] = message.imageUrl;
        dic[@"thumb"] = [NSString stringWithFormat:@"data:image/png;base64,%@", [UIImagePNGRepresentation(message.thumbnailImage) base64EncodedStringWithOptions:0]];
        dic[@"extra"] = message.extra;
    }
    else if ([messageContent isKindOfClass:[RCCommandNotificationMessage class]]){
        RCCommandNotificationMessage * message = (RCCommandNotificationMessage*)messageContent;
        dic[@"type"] = @"notify";
        dic[@"name"] = message.name;
        dic[@"data"] = message.data;
    }
    else if ([messageContent isKindOfClass:[RCRichContentMessage class]]) {
        RCRichContentMessage * message = (RCRichContentMessage*)messageContent;
        dic[@"type"] = @"rich";
        dic[@"title"] = message.title;
        dic[@"digest"] = message.digest;
        dic[@"image"] = message.imageURL;
        dic[@"url"] = message.url;
        dic[@"extra"] = message.extra;
    }
    else {
        dic[@"type"] = @"unknown";
    }
    return dic;
}

+ (NSString *)_converConversationType:(RCConversationType *)type {
    if (type == 0) {
        return @"none";
    } else if (type == ConversationType_PRIVATE) {
        return @"private";
    } else if (type == ConversationType_DISCUSSION) {
        return @"discussion";
    } else if (type == ConversationType_GROUP) {
        return @"group";
    } else if (type == ConversationType_CHATROOM) {
        return @"chatroom";
    } else if (type == ConversationType_CUSTOMERSERVICE) {
        return @"customer_service";
    } else if (type == ConversationType_SYSTEM) {
        return @"system";
    } else if (type == ConversationType_APPSERVICE) {
        return @"app_service";
    } else if (type == ConversationType_PUBLICSERVICE) {
        return @"public_service";
    } else if (type == ConversationType_PUSHSERVICE) {
        return @"push_service";
    }
    return @"";
}

+ (RCConversationType *)_converConversationTypeString:(NSString *)type {
    if ([type isEqualToString: @"private"]) {
        return ConversationType_PRIVATE;
    } else if ([type isEqualToString:@"discussion"]) {
        return ConversationType_DISCUSSION;
    } else if ([type isEqualToString:@"group"]) {
        return ConversationType_GROUP;
    } else if ([type isEqualToString: @"chatroom"]) {
        return ConversationType_CHATROOM;
    } else if ([type isEqualToString: @"customer_service"]) {
        return ConversationType_CUSTOMERSERVICE;
    } else if ([type isEqualToString: @"system"]) {
        return ConversationType_SYSTEM;
    } else if ([type isEqualToString: @"app_service"]) {
        return ConversationType_APPSERVICE;
    } else if ([type isEqualToString: @"public_service"]) {
        return ConversationType_PUBLICSERVICE;
    } else if ([type isEqualToString: @"push_service"]) {
        return ConversationType_PUSHSERVICE;
    } else {
        return ConversationType_PRIVATE;
    }
}

+ (NSArray *) _convertConversationTypeArray: (NSArray *)array {
    NSMutableArray * ret = [[NSMutableArray alloc] init];
    
    for(NSString *typeName in array) {
        NSLog(@"typeName: %@", typeName);
        RCConversationType type = [self.class _converConversationTypeString:typeName];
        [ret addObject:@(type)];
    }
    NSLog(@"ret: %@", ret);
    return (NSArray *)ret;
}


@end
