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

    //监听融云网络状态
    
    
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
        //[[self shareClient] setRCConnectionStatusChangeDelegate:self];
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
    resolve([self.class _convertConnectionSatus: status]);
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

//未读消息总数
RCT_EXPORT_METHOD(getTotalUnreadCount:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject)
{
    int totalUnreadCount = [[self shareClient] getTotalUnreadCount];
    resolve([NSString stringWithFormat:@"%d", totalUnreadCount]);
}

//设置会话是否置顶
RCT_EXPORT_METHOD(setConversationToTop:(NSString *)conversationType targetId:(NSString *)targetId isTop:(BOOL)isTop) {
    [[self shareClient] setConversationToTop:[self.class _converConversationTypeString:conversationType] targetId:targetId isTop:isTop];
}

//获取会话列表
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

//获取会话
RCT_EXPORT_METHOD(getConversation:(RCConversationType)conversationType targetId:(NSString *)targetId resolve:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject)
{
    RCConversation *conv = [[self shareClient] getConversation:conversationType targetId:targetId];
    resolve([self.class _convertConversation:conv]);
}

//发送已读回执
RCT_EXPORT_METHOD(sendReadReceiptMessage:(RCConversationType)conversationType targetId:(NSString *)targetId time:(nonnull NSNumber *)time)
{
    //NSLog(@"Long long timestamp %ld", time);
    [[self shareClient] sendReadReceiptMessage:conversationType targetId:targetId time:(long long)time];
}

//清除会话列表
RCT_EXPORT_METHOD(clearConversations: (NSArray *)conversationTypeList resolve:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject)
{
    NSArray * typeList = [self.class _convertConversationTypeArray: conversationTypeList];
    BOOL result = [[self shareClient] clearConversations:typeList];
    resolve(@(result));
}

//清除会话
RCT_EXPORT_METHOD(removeConversation: (RCConversationType)conversationType  targetId:(NSString *)targetId)
{
    [[self shareClient] removeConversation:conversationType targetId:targetId];
}

// 设置消息的接收状态
RCT_EXPORT_METHOD(setMessageReceivedStatus:(long)messageId receivedStatus:(RCReceivedStatus)receivedStatus)
{
    [[self shareClient] setMessageReceivedStatus:messageId receivedStatus:receivedStatus];
}

//获取最新的消息
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
//发送消息
RCT_EXPORT_METHOD(sendMessage: (RCConversationType) type targetId:(NSString*) targetId content:(RCMessageContent*) content
                  pushContent: (NSString*) pushContent pushData:(NSString*) pushData
                  resolve:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject)
{
    RCMessage* msg = [[self shareClient] sendMessage:type targetId:targetId content:content pushContent:pushContent
                success:^(long messageId){
                    [_bridge.eventDispatcher sendAppEventWithName:@"RCMsgSendOk" body:@(messageId)];
                } error:^(RCErrorCode code, long messageId){
                    NSMutableDictionary* dic = [NSMutableDictionary new];
                    dic[@"messageId"] = @(messageId);
                    dic[@"errCode"] = @((int)code);
                    [_bridge.eventDispatcher sendAppEventWithName:@"RCMsgSendFailed" body:dic];
                }];
    resolve([self.class _convertMessage:msg]);
}
//删除消息
RCT_EXPORT_METHOD(deleteMessages:(NSArray *)messageIds)
{
    [[self shareClient] deleteMessages:messageIds];
}
//清除消息未读状态
RCT_EXPORT_METHOD(clearMessagesUnreadStatus:(NSString *)conversationType targetId:(NSString *)targetId)
{
    [[self shareClient] clearMessagesUnreadStatus:[self.class _converConversationTypeString:conversationType] targetId:targetId];
}
//加入聊天室
RCT_EXPORT_METHOD(joinChatRoom: (NSString *)targetId messageCount:(int)messageCount resolve:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject) {
    
    [[self shareClient] joinChatRoom:targetId messageCount:messageCount success:^() {
        resolve(@"success");
      } error:^(RCErrorCode code){
          //reject(@"failed");
      }];
}

//创建讨论组
RCT_EXPORT_METHOD(createDiscussion:(NSString *)name userIdList:(NSArray *)userIdList resolve:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject) {
    [[self shareClient] createDiscussion:name userIdList:userIdList success:^(RCDiscussion * discussion) {
        
        resolve([self.class _convertDiscussion: discussion]);
        
        
    } error:^(RCErrorCode status) {
        NSLog(@"%d", status);
    }];
}

//讨论组加人，将用户加入讨论组
RCT_EXPORT_METHOD(addMemberToDiscussion:(NSString *)discussionId userIdList:(NSArray *)userIdList resolve:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject) {
    
}

//讨论组踢人，将用户移出讨论组
RCT_EXPORT_METHOD(removeMemberFromDiscussion:(NSString *)discussionId userId:(NSString *)userId resolve:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject) {
    
}

//退出当前讨论组
RCT_EXPORT_METHOD(quitDiscussion:(NSString *)discussionId resolve:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject) {
    
}

//获取讨论组的信息
RCT_EXPORT_METHOD(getDiscussion:(NSString *)discussionId resolve:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject) {
    
}

//设置讨论组名称
RCT_EXPORT_METHOD(setDiscussionName:(NSString *)discussionId name:(NSString *)discussionName resolve:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject) {
    
}

//设置讨论组是否开放加人权限
RCT_EXPORT_METHOD(setDiscussionInviteStatus:(NSString *)targetId isOpen:(BOOL)isOpen resolve:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject) {
    
}

//是否可以录音
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
    [_bridge.eventDispatcher sendAppEventWithName:@"RCMsgRecved" body:[self.class _convertMessage:message]];
}

- (void)onConnectionStatusChanged:(RCConnectionStatus)status {
    NSLog(@"onConnectionStatusChanged: %d", status);
    [_bridge.eventDispatcher sendAppEventWithName:@"RCConnStatusChanged" body:@{ @"status": [self.class _convertConnectionSatus:status]}];
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
    } else if ([messageContent isKindOfClass:[RCDiscussionNotificationMessage class]]) {
        RCDiscussionNotificationMessage *message = (RCDiscussionNotificationMessage *)messageContent;
        dic[@"type"] = @(message.type);
        dic[@"operatorId"] = message.operatorId;
        dic[@"senderUserInfo"] = [self.class _convertUserInfo: message.senderUserInfo];
    }else {
        dic[@"type"] = @"unknown";
    }
    return dic;
}

+ (NSDictionary *)_convertDiscussion: (RCDiscussion *)discussion {
    NSMutableDictionary *dic = [NSMutableDictionary new];
    dic[@"name"] = discussion.discussionName;
    dic[@"discussionId"] = discussion.discussionId;
    dic[@"creatorId"] = discussion.creatorId;
    dic[@"memberIdList"] = discussion.memberIdList;
    dic[@"inviteStatus"] = @(discussion.inviteStatus);
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
        RCConversationType type = [self.class _converConversationTypeString:typeName];
        [ret addObject:@(type)];
    }
    return (NSArray *)ret;
}

+ (NSArray *)_jsArrayToObjectArray: (NSArray *)array {
    NSMutableArray * ret = [[NSMutableArray alloc] init];
    for(NSString * str in array) {
        [ret addObject: str];
    }
    return (NSArray *)ret;
}

+ (NSDictionary *)_convertUserInfo: (RCUserInfo *)user {
    NSMutableDictionary * ret = [[NSMutableArray alloc] init];
    [ret setValue:[user name] forKeyPath:@"name"];
    [ret setValue:[user userId] forKeyPath:@"userId"];
    [ret setValue:[user portraitUri] forKeyPath:@"portraitUri"];
    return ret;
}

+ (NSString *)_convertConnectionSatus: (RCConnectionStatus)status {
    
    NSString * ret;
    switch (status) {
        case ConnectionStatus_UNKNOWN:
            ret = @"UNKNOWN";
            break;
        case ConnectionStatus_Connected:
            ret = @"Connected";
            break;
        case ConnectionStatus_NETWORK_UNAVAILABLE:
            ret = @"NETWORK_UNAVAILABLE";
            break;
        case ConnectionStatus_AIRPLANE_MODE:
            ret = @"AIRPLANE_MODE";
            break;
        case ConnectionStatus_Cellular_2G:
            ret = @"Cellular_2G";
            break;
        case ConnectionStatus_Cellular_3G_4G:
            ret = @"Cellular_3G_4G";
            break;
        case ConnectionStatus_WIFI:
            ret = @"WIFI";
            break;
        case ConnectionStatus_KICKED_OFFLINE_BY_OTHER_CLIENT:
            ret = @"KICKED_OFFLINE_BY_OTHER_CLIENT";
            break;
        case ConnectionStatus_LOGIN_ON_WEB:
            ret = @"KICKED_OFFLINE_BY_OTHER_CLIENT";
            break;
        case ConnectionStatus_SERVER_INVALID:
            ret = @"SERVER_INVALID";
            break;
        case ConnectionStatus_VALIDATE_INVALID:
            ret = @"VALIDATE_INVALID";
            break;
        case ConnectionStatus_Connecting:
            ret = @"Connecting";
            break;
        case ConnectionStatus_Unconnected:
            ret = @"Unconnected";
            break;
        case ConnectionStatus_SignUp:
            ret = @"SignUp";
            break;
        case ConnectionStatus_TOKEN_INCORRECT:
            ret = @"TOKEN_INCORRECT";
            break;
        case ConnectionStatus_DISCONN_EXCEPTION:
            ret = @"DISCONN_EXCEPTION";
            break;
        default:
            ret = @"UNKNOWN";
            break;
    }
    
    return ret;
}

@end
