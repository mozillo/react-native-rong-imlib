/**
 * Created by tdzl2003 on 4/13/16.
 */

import {Alert, NativeModules, NativeAppEventEmitter} from 'react-native';
import EventEmitter from 'react-native/Libraries/EventEmitter/EventEmitter';

const ConversationType = {
	APP_SERVICE: 'appService',
	CHATROOM: 'chatroom',
	CUSTOM_SERVICE: 'customerService',
	DISCUSSION: 'discussion',
	GROUP: 'group',
	PRIVATE: 'private',
	PUBLISH_SERVICE: 'publishService',
	PUSH_SERVICE: 'pushService',
	SYSTEM: 'system', 
};
const RongIMLib = NativeModules.RongIMLib;

const eventEmitter = new EventEmitter();

export default Object.assign(exports, RongIMLib, ConversationType);

exports.eventEmitter = eventEmitter;
exports.addListener = eventEmitter.addListener.bind(eventEmitter);
exports.once = eventEmitter.once.bind(eventEmitter);
exports.removeAllListeners = eventEmitter.removeAllListeners.bind(eventEmitter);
exports.removeCurrentListener = eventEmitter.removeCurrentListener.bind(eventEmitter);

NativeAppEventEmitter.addListener('rongIMMsgRecved', msg => {
  eventEmitter.emit('msgRecved', msg);
});
