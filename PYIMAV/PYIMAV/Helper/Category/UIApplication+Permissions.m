//
//  UIApplication-Permissions.m
//  UIApplication-Permissions Sample
//
//  Created by Jack Rostron on 12/01/2014.
//  Copyright (c) 2014 Rostron. All rights reserved.
//

#import "UIApplication+Permissions.h"
#import <objc/runtime.h>

//Import required frameworks
@import AddressBook;
@import AssetsLibrary;
@import AVFoundation;
@import CoreBluetooth;
@import CoreLocation;
@import CoreMotion;
@import EventKit;

typedef void (^LocationSuccessCallback)(void);
typedef void (^LocationFailureCallback)(void);

static char PermissionsLocationManagerPropertyKey;
static char PermissionsLocationBlockSuccessPropertyKey;
static char PermissionsLocationBlockFailurePropertyKey;

@interface UIApplication () <CLLocationManagerDelegate>
@property (nonatomic, retain) CLLocationManager *permissionsLocationManager;
@property (nonatomic, copy) LocationSuccessCallback locationSuccessCallbackProperty;
@property (nonatomic, copy) LocationFailureCallback locationFailureCallbackProperty;
@end


@implementation UIApplication (Permissions)


#pragma mark - Check permissions
-(kPermissionAccess)hasAccessToBluetoothLE {
    switch ([[[CBCentralManager alloc] init] state]) {
        case CBCentralManagerStateUnsupported:
            return kPermissionAccessUnsupported;
            break;
            
        case EKAuthorizationStatusNotDetermined:
            return kPermissionAccessNotRequest;
            break;
            
        case CBCentralManagerStateUnauthorized:
            return kPermissionAccessDenied;
            break;
            
        default:
            return kPermissionAccessGranted;
            break;
    }
}

-(kPermissionAccess)hasAccessToCalendar {
    switch ([EKEventStore authorizationStatusForEntityType:EKEntityTypeEvent]) {
        case EKAuthorizationStatusAuthorized:
            return kPermissionAccessGranted;
            break;
            
        case EKAuthorizationStatusNotDetermined:
            return kPermissionAccessNotRequest;
            break;
            
        case EKAuthorizationStatusDenied:
            return kPermissionAccessDenied;
            break;
            
        case EKAuthorizationStatusRestricted:
            return kPermissionAccessRestricted;
            break;
            
        default:
            return kPermissionAccessUnknown;
            break;
    }
}

-(kPermissionAccess)hasAccessToContacts {
    switch (ABAddressBookGetAuthorizationStatus()) {
        case kABAuthorizationStatusAuthorized:
            return kPermissionAccessGranted;
            break;
            
        case kABAuthorizationStatusDenied:
            return kPermissionAccessDenied;
            break;
            
        case EKAuthorizationStatusNotDetermined:
            return kPermissionAccessNotRequest;
            break;
            
        case kABAuthorizationStatusRestricted:
            return kPermissionAccessRestricted;
            break;
            
        default:
            return kPermissionAccessUnknown;
            break;
    }
}

-(kPermissionAccess)hasAccessToLocation {
    switch ([CLLocationManager authorizationStatus]) {
        case kCLAuthorizationStatusAuthorized:
//        case kCLAuthorizationStatusAuthorizedAlways:
        case kCLAuthorizationStatusAuthorizedWhenInUse:
            return kPermissionAccessGranted;
            break;
            
        case kCLAuthorizationStatusDenied:
            return kPermissionAccessDenied;
            break;
            
        case EKAuthorizationStatusNotDetermined:
            return kPermissionAccessNotRequest;
            break;
            
        case kCLAuthorizationStatusRestricted:
            return kPermissionAccessRestricted;
            break;
            
        default:
            return kPermissionAccessUnknown;
            break;
    }
    return kPermissionAccessUnknown;
}

-(kPermissionAccess)hasAccessToPhotos {
    switch ([ALAssetsLibrary authorizationStatus]) {
        case ALAuthorizationStatusAuthorized:
            return kPermissionAccessGranted;
            break;
            
        case EKAuthorizationStatusNotDetermined:
            return kPermissionAccessNotRequest;
            break;
            
        case ALAuthorizationStatusDenied:
            return kPermissionAccessDenied;
            break;
            
        case ALAuthorizationStatusRestricted:
            return kPermissionAccessRestricted;
            break;
            
        default:
            return kPermissionAccessUnknown;
            break;
    }
}

-(kPermissionAccess)hasAccessToReminders {
    switch ([EKEventStore authorizationStatusForEntityType:EKEntityTypeReminder]) {
        case EKAuthorizationStatusAuthorized:
            return kPermissionAccessGranted;
            break;
            
        case EKAuthorizationStatusNotDetermined:
            return kPermissionAccessNotRequest;
            break;
            
        case EKAuthorizationStatusDenied:
            return kPermissionAccessDenied;
            break;
            
        case EKAuthorizationStatusRestricted:
            return kPermissionAccessRestricted;
            break;
            
        default:
            return kPermissionAccessUnknown;
            break;
    }
    return kPermissionAccessUnknown;
}

-(kPermissionAccess)hasAccessToMicrophone {
    switch ([AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeAudio]) {
        case AVAuthorizationStatusAuthorized:
            return kPermissionAccessGranted;
            break;
            
        case AVAuthorizationStatusNotDetermined:
            return kPermissionAccessNotRequest;
            break;
            
        case AVAuthorizationStatusDenied:
            return kPermissionAccessDenied;
            break;
            
        case AVAuthorizationStatusRestricted:
            return kPermissionAccessRestricted;
            break;
            
        default:
            return kPermissionAccessUnknown;
            break;
    }
    return kPermissionAccessUnknown;
}

-(kPermissionAccess)hasAccessToCamera {
    [UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera];
    AVAuthorizationStatus authStatus = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo];
    switch (authStatus) {
        case EKAuthorizationStatusAuthorized:
            return kPermissionAccessGranted;
            break;
            
        case EKAuthorizationStatusNotDetermined:
            return kPermissionAccessNotRequest;
            break;
            
        case EKAuthorizationStatusDenied:
            return kPermissionAccessDenied;
            break;
            
        case EKAuthorizationStatusRestricted:
            return kPermissionAccessRestricted;
            break;
            
        default:
            return kPermissionAccessUnknown;
            break;
    }
    return kPermissionAccessUnknown;
}


#pragma mark - Request permissions
-(void)requestAccessToCalendarWithSuccess:(void(^)(void))accessGranted andFailure:(void(^)(void))accessDenied {
    EKEventStore *eventStore = [[EKEventStore alloc] init];
    [eventStore requestAccessToEntityType:EKEntityTypeEvent completion:^(BOOL granted, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (granted) {
                accessGranted();
            } else {
                accessDenied();
            }
        });
    }];
}

-(void)requestAccessToContactsWithSuccess:(void(^)(void))accessGranted andFailure:(void(^)(void))accessDenied {
    ABAddressBookRef addressBook = ABAddressBookCreateWithOptions(NULL, NULL);
    if(addressBook) {
        ABAddressBookRequestAccessWithCompletion(addressBook, ^(bool granted, CFErrorRef error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (granted) {
                    accessGranted();
                } else {
                    accessDenied();
                }
            });
        });
    }
}

-(void)requestAccessToMicrophoneWithSuccess:(void(^)(void))accessGranted andFailure:(void(^)(void))accessDenied {
    AVAudioSession *session = [[AVAudioSession alloc] init];
    [session requestRecordPermission:^(BOOL granted) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (granted) {
                accessGranted();
            } else {
                accessDenied();
            }
        });
    }];
}

-(void)requestAccessToMotionWithSuccess:(void(^)(void))accessGranted {
    CMMotionActivityManager *motionManager = [[CMMotionActivityManager alloc] init];
    NSOperationQueue *motionQueue = [[NSOperationQueue alloc] init];
    [motionManager startActivityUpdatesToQueue:motionQueue withHandler:^(CMMotionActivity *activity) {
        accessGranted();
        [motionManager stopActivityUpdates];
    }];
}

-(void)requestAccessToPhotosWithSuccess:(void(^)(void))accessGranted andFailure:(void(^)(void))accessDenied {
    ALAssetsLibrary *assetsLibrary = [[ALAssetsLibrary alloc] init];
    [assetsLibrary enumerateGroupsWithTypes:ALAssetsGroupAlbum usingBlock:^(ALAssetsGroup *group, BOOL *stop) {
        accessGranted();
    } failureBlock:^(NSError *error) {
        accessDenied();
    }];
}

-(void)requestAccessToCameraWithSuccess:(void(^)(void))accessGranted andFailure:(void(^)(void))accessDenied {
    [UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera];
    AVAuthorizationStatus authStatus = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo];
    if(authStatus == AVAuthorizationStatusNotDetermined){
        [AVCaptureDevice requestAccessForMediaType:AVMediaTypeVideo completionHandler:^(BOOL granted) {
            if (granted) {
                accessGranted();
            } else {
                accessDenied();
            }
        }];
    }
    else{
        accessDenied();
    }
}




-(void)requestAccessToRemindersWithSuccess:(void(^)(void))accessGranted andFailure:(void(^)(void))accessDenied {
    EKEventStore *eventStore = [[EKEventStore alloc] init];
    [eventStore requestAccessToEntityType:EKEntityTypeReminder completion:^(BOOL granted, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (granted) {
                accessGranted();
            } else {
                accessDenied();
            }
        });
    }];
}


#pragma mark - Needs investigating
/*
 -(void)requestAccessToBluetoothLEWithSuccess:(void(^)(void))accessGranted {
 //REQUIRES DELEGATE - NEEDS RETHINKING
 }
 */

-(void)requestAccessToLocationWithSuccess:(void(^)(void))accessGranted andFailure:(void(^)(void))accessDenied {
    self.permissionsLocationManager = [[CLLocationManager alloc] init];
    self.permissionsLocationManager.delegate = self;
    
    self.locationSuccessCallbackProperty = accessGranted;
    self.locationFailureCallbackProperty = accessDenied;
    [self.permissionsLocationManager startUpdatingLocation];
}


#pragma mark - Location manager injection
-(CLLocationManager *)permissionsLocationManager {
    return objc_getAssociatedObject(self, &PermissionsLocationManagerPropertyKey);
}

-(void)setPermissionsLocationManager:(CLLocationManager *)manager {
    objc_setAssociatedObject(self, &PermissionsLocationManagerPropertyKey, manager, OBJC_ASSOCIATION_RETAIN);
}

-(LocationSuccessCallback)locationSuccessCallbackProperty {
    return objc_getAssociatedObject(self, &PermissionsLocationBlockSuccessPropertyKey);
}

-(void)setLocationSuccessCallbackProperty:(LocationSuccessCallback)locationCallbackProperty {
    objc_setAssociatedObject(self, &PermissionsLocationBlockSuccessPropertyKey, locationCallbackProperty, OBJC_ASSOCIATION_COPY);
}

-(LocationFailureCallback)locationFailureCallbackProperty {
    return objc_getAssociatedObject(self, &PermissionsLocationBlockFailurePropertyKey);
}

-(void)setLocationFailureCallbackProperty:(LocationFailureCallback)locationFailureCallbackProperty {
    objc_setAssociatedObject(self, &PermissionsLocationBlockFailurePropertyKey, locationFailureCallbackProperty, OBJC_ASSOCIATION_COPY);
}


#pragma mark - Location manager delegate
- (void)locationManager:(CLLocationManager *)manager didChangeAuthorizationStatus:(CLAuthorizationStatus)status {
    if (status == kCLAuthorizationStatusAuthorized) {
        self.locationSuccessCallbackProperty();
    } else if (status != kCLAuthorizationStatusNotDetermined) {
        self.locationFailureCallbackProperty();
    }
}

@end
