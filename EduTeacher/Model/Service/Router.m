//
//  Router.m
//  EduTeacher
//
//  Created by Andrew Kochulab on 11.02.16.
//  Copyright © 2016 Andrew Kochulab. All rights reserved.
//

#import "Router.h"
#import <ifaddrs.h>
#import <arpa/inet.h>
#include <net/if.h>

@implementation Router

#define IP_ADDR_IPv4    @"ipv4"
#define IP_ADDR_IPv6    @"ipv6"

#define IOS_CELLULAR    @"pdp_ip0"
#define IOS_WIFI        @"en0"
#define IOS_VPN         @"utun0"

#pragma mark - Initialization

- (instancetype) init {
    self = [super init];
    
    if (self) {
        // Setup client IP address
        _clientIP = [self getClientIPAddress];
    }
    
    return self;
}

#pragma mark - Instance methods

- (void) setupServerWithIPAddress:(NSString *)ipAddress {
    // Setup server IP address
    self.serverIP = ipAddress;
    
    // Setup server address
    self.serverURL = [self getServerURL];
}

- (NSString *) getServerIPAddressByCode:(NSString *)code {
    NSString *baseIPAddress = nil;
    
    NSRange range = [self.clientIP rangeOfString:@"." options:NSBackwardsSearch];
    baseIPAddress = [self.clientIP substringToIndex:range.location];
    
    return [[baseIPAddress stringByAppendingString:@"."] stringByAppendingString:code];
}

- (NSString *) getClientIPAddress {
    NSArray *searchArray = @[IOS_VPN @"/" IP_ADDR_IPv4,
                             IOS_VPN @"/" IP_ADDR_IPv6,
                             IOS_WIFI @"/" IP_ADDR_IPv4,
                             IOS_WIFI @"/" IP_ADDR_IPv6,
                             IOS_CELLULAR @"/" IP_ADDR_IPv4,
                             IOS_CELLULAR @"/" IP_ADDR_IPv6];
    
    NSDictionary *addresses = [self getIPAddresses];

    __block NSString *address;
    [searchArray enumerateObjectsUsingBlock:
        ^(NSString *key, NSUInteger idx, BOOL *stop) {
            address = addresses[key];
            if(address) *stop = YES;
        }
    ];

    return address ? address : @"0.0.0.0";
}

- (NSDictionary *) getIPAddresses {
    NSMutableDictionary *addresses = [NSMutableDictionary dictionaryWithCapacity:8];
    
    // retrieve the current interfaces - returns 0 on success
    struct ifaddrs *interfaces;
    if(!getifaddrs(&interfaces)) {
        // Loop through linked list of interfaces
        struct ifaddrs *interface;
        for(interface=interfaces; interface; interface=interface->ifa_next) {
            /*if(!(interface->ifa_flags & IFF_UP) / || (interface->ifa_flags & IFF_LOOPBACK) / ) {
                continue; // deeply nested code harder to read
            }*/
            const struct sockaddr_in *addr = (const struct sockaddr_in*)interface->ifa_addr;
            char addrBuf[ MAX(INET_ADDRSTRLEN, INET6_ADDRSTRLEN) ];
            if(addr && (addr->sin_family==AF_INET || addr->sin_family==AF_INET6)) {
                NSString *name = [NSString stringWithUTF8String:interface->ifa_name];
                NSString *type;
                if(addr->sin_family == AF_INET) {
                    if(inet_ntop(AF_INET, &addr->sin_addr, addrBuf, INET_ADDRSTRLEN)) {
                        type = IP_ADDR_IPv4;
                    }
                } else {
                    const struct sockaddr_in6 *addr6 = (const struct sockaddr_in6*)interface->ifa_addr;
                    if(inet_ntop(AF_INET6, &addr6->sin6_addr, addrBuf, INET6_ADDRSTRLEN)) {
                        type = IP_ADDR_IPv6;
                    }
                }
                if(type) {
                    NSString *key = [NSString stringWithFormat:@"%@/%@", name, type];
                    addresses[key] = [NSString stringWithUTF8String:addrBuf];
                }
            }
        }
        // Free memory
        freeifaddrs(interfaces);
    }
    return [addresses count] ? addresses : nil;
}

- (NSString *) getServerURL {
    return [[@"http://" stringByAppendingString:self.serverIP] stringByAppendingString:@":8080/SignalR/"];
}

#pragma mark - Router methods

+ (BOOL) isValidIPAddress:(NSString *)ipAddress {
    const char *utf8 = [ipAddress UTF8String];
    
    // Check valid IPv4
    struct in_addr ipV4;
    int success = inet_pton(AF_INET, utf8, &(ipV4.s_addr));
    
    if (success != 1) {
        // Check valid IPv6
        struct in6_addr ipV6;
        success = inet_pton(AF_INET6, utf8, &ipV6);
    }
    
    return (success == 1);
}

@end
