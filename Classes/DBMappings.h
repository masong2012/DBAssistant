//
//  DBMapping.h
//  Database
//
//  Created by MaSong on 15/8/20.
//  Copyright (c) 2015年 MaSong. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface PropertyToColumnMapping : NSObject
@property (readonly,nonatomic) NSString *propertyName;
@property (readonly,nonatomic) NSString *propertyType;

@property (readonly,nonatomic) NSString *sqlColumnName;
@property (readonly,nonatomic) NSString *sqlColumnType;

@property (assign,nonatomic) BOOL unique;
@property (assign,nonatomic) BOOL notNull;
@property (strong,nonatomic) NSString *defaultValue;
@property (strong,nonatomic) NSString *check;
@property (assign,nonatomic) NSUInteger length;

@end



@interface ModelToTableMapping : NSObject
@property (readonly,nonatomic) NSUInteger count;
@property (readonly,nonatomic) NSArray *primaryKeys;
@property (readonly,nonatomic) NSDictionary *allMappings;


- (id)initWithPropertyNames:(NSArray*)propertyNames
             propertyTypes:(NSArray*)propertyTypes
                primaryKeys:(NSArray*)primaryKeys
  propertyToColumnMappings:(NSDictionary*)mappings;

- (PropertyToColumnMapping*)propertyToColumnMappingAtIndex:(int)index;
- (PropertyToColumnMapping*)propertyToColumnMappingForPropertyName:(NSString*)propertyName;
- (PropertyToColumnMapping*)propertyToColumnMappingForColumnName:(NSString*)columnName;

@end
