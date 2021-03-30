var exec = require('cordova/exec');

var RTMPBroadcaster = {};

RTMPBroadcaster.showCameraFeed = (success, error) => {
    exec(success, error, 'RTMPBroadcaster', 'showCameraFeed');
};

RTMPBroadcaster.removeCameraFeed = (success, error) => {
    exec(success, error, 'RTMPBroadcaster', 'removeCameraFeed');
};

RTMPBroadcaster.rotateCamera = (success, error) => {
    exec(success, error, 'RTMPBroadcaster', 'rotateCamera');
};

RTMPBroadcaster.startStream = (url, id, success, error) => {
    exec(success, error, 'RTMPBroadcaster', 'startStream', [url, id]);
};

RTMPBroadcaster.stopStream = (success, error) => {
    exec(success, error, 'RTMPBroadcaster', 'stopStream');
};

module.exports = RTMPBroadcaster;
