//
//  DBMapping.m
//  Database
//
//  Created by MaSong on 15/8/20.
//  Copyright (c) 2015年 MaSong. All rights reserved.
//

#import "DBMappings.h"
#import "DBHelpers.h"
#import "NSObject+DB.h"

#pragma mark -
#pragma mark - PropertyToColumnMap
@interface PropertyToColumnMapping(){
    __strong NSString* _sqlColumnName;
    __strong NSString* _sqlColumnType;
    __strong NSString* _propertyName;
    __strong NSString* _propertyType;
}

@property(copy,nonatomic)NSString* sqlColumnName;
@property(copy,nonatomic)NSString* sqlColumnType;
@property(copy,nonatomic)NSString* propertyName;
@property(copy,nonatomic)NSString* propertyType;

-(id)initWithColumnName:(NSString *)columnName
             columnType:(NSString *)columnType
           propertyName:(NSString *)propertyName
           propertyType:(NSString *)propertyType;
@end

@implementation PropertyToColumnMapping

-(id)initWithColumnName:(NSString *)columnName
             columnType:(NSString *)columnType
           propertyName:(NSString *)propertyName
           propertyType:(NSString *)propertyType{
    
    if(self = [super init]){
        
        _sqlColumnName = [columnName copy];
        _sqlColumnType = [columnType copy];
        _propertyName = [propertyName copy];
        _propertyType = [propertyType copy];
    }
    return self;
}

@end



#pragma mark -
#pragma mark - ModelToTableMapping
@interface ModelToTableMapping(){
    __strong NSMutableDictionary* _propertyNameDic;
    __strong NSMutableDictionary* _sqlColumnNameDic;
    __strong NSMutableDictionary* _propertyToColumnMappingDic;
    __strong NSArray* _primaryKeys;
}

-(void)addColumnName:(NSString *)columnName
          columnType:(NSString *)columnType
        propertyName:(NSString *)propertyName
        propertyType:(NSString *)propertyType;
@end

@implementation ModelToTableMapping
-(id)initWithPropertyNames:(NSArray*)propertyNames
             propertyTypes:(NSArray*)propertyTypes
               primaryKeys:(NSArray*)primaryKeys
  propertyToColumnMappings:(NSDictionary*)mappings{
    
    
    if (self = [super init]) {
        
        _primaryKeys = [[NSArray alloc]initWithArray:primaryKeys ?: @[]];
        _propertyNameDic = [NSMutableDictionary new];
        _sqlColumnNameDic = [NSMutableDictionary new];
        _propertyToColumnMappingDic = [NSMutableDictionary new];
        
        NSString  *column_name,*column_type,*property_name,*property_type;
        
        if(mappings.count > 0){
            
            for(NSString *propertyName in mappings.allKeys){
                
                NSString *columnName = [mappings objectForKey:propertyName];
                
                if ([columnName isNotEmpty]) {
                    
                    NSUInteger index = [propertyNames indexOfObject:propertyName];
                    
                    if (index != NSNotFound) {
                        NSString *property_type = [propertyTypes objectAtIndex:index];
                        NSString *column_type = dbTypeFromObjcType(property_type);
                        
                        [self addColumnName:column_name
                                 columnType:column_type
                               propertyName:property_name
                               propertyType:property_type];
                        
                    } else {
                        NSLog(@"#ERROR,Map[%@:%@],propertyName %@ not in propertyNames",propertyName,columnName,propertyName);
                    }
        
                }
                
            }
        }
        
        for (int i = 0; i < propertyNames.count; i++) {
            
            property_name = [propertyNames objectAtIndex:i];
            property_type = [propertyTypes objectAtIndex:i];

            column_name = property_name;
            column_type = dbTypeFromObjcType(property_type);
            
            if ([self propertyToColumnMappingForPropertyName:property_name] ||
                [self propertyToColumnMappingForColumnName:column_name]) {
                continue;
            }
            
            [self addColumnName:column_name
                     columnType:column_type
                   propertyName:property_name
                   propertyType:property_type];
        }
        
        if(_primaryKeys.count == 0){
            _primaryKeys = [NSArray arrayWithObject:DBRowId];
        }
        
        for (NSString* pkName in _primaryKeys) {
            if([pkName.lowercaseString isEqualToString:DBRowId] &&
               [self propertyToColumnMappingForColumnName:pkName] == nil){
                [self addColumnName:pkName
                         columnType:DBTypeInt
                       propertyName:pkName
                       propertyType:@"int"];
                break;
            }
        }
        
    }
    return self;
}




-(void)addColumnName:(NSString *)columnName
          columnType:(NSString *)columnType
        propertyName:(NSString *)propertyName
        propertyType:(NSString *)propertyType{
    
        PropertyToColumnMapping *pcMapping = [[PropertyToColumnMapping alloc]initWithColumnName:columnName columnType:columnType propertyName:propertyName propertyType:propertyType];
        
        // default settings
        NSDictionary *defaultValueDic = [[self class] defaultValues];
        NSDictionary *lengthDic = [[self class] lengthValues];
        NSDictionary *checkValueDic = [[self class] checkValues];
        NSArray *uniqueArray = [[self class] uniqueValues];
        NSArray *notNullArray = [[self class] notNullValues];
        
        //default value
        for(NSString *key in defaultValueDic.allKeys){
            if ([key isEqualToString:columnName] || [key isEqualToString:propertyName]){
                id value = [defaultValueDic objectForKey:key];
                pcMapping.defaultValue = value;
                break;
            }
        }
    
        //length
        for(NSString *key in lengthDic.allKeys){
            if ([key isEqualToString:columnName] || [key isEqualToString:propertyName]){
                
                id value = [defaultValueDic objectForKey:key];
                pcMapping.length = [value integerValue];
                break;
            }
        }
    
        //check
        for(NSString *key in checkValueDic.allKeys){
            if ([key isEqualToString:columnName] || [key isEqualToString:propertyName]){
                id value = [checkValueDic objectForKey:key];
                pcMapping.check = value;
                break;
            }
        }
    
        //uniqure
        for(NSString *key in uniqueArray){
            if ([key isEqualToString:columnName] || [key isEqualToString:propertyName]){
                pcMapping.unique = YES;
                break;
            }
        }
        
       //notNull
        for(NSString *key in notNullArray){
            if ([key isEqualToString:columnName] || [key isEqualToString:propertyName]){
                pcMapping.notNull = YES;
                break;
            }
        }
        
        if ([pcMapping.propertyName isNotEmpty]) {
            [_propertyNameDic setObject:pcMapping forKey:pcMapping.propertyName];
        }
        
        if ([pcMapping.sqlColumnName isNotEmpty]) {
            [_sqlColumnNameDic setObject:pcMapping forKey:pcMapping.sqlColumnName];
        }
        
        [_propertyToColumnMappingDic setObject:columnName forKey:propertyName];
}

-(NSArray *)primaryKeys{
    return _primaryKeys;
}

-(NSUInteger)count{
    return _propertyNameDic.count;
}

-(NSDictionary *)allMappings{
    return _propertyToColumnMappingDic;
}


-(PropertyToColumnMapping*)propertyToColumnMappingAtIndex:(int)index{
    if (index < _propertyNameDic.count) {
        id key = _propertyNameDic.allKeys[index];
        return _propertyNameDic[key];
    }
    return nil;
}

-(PropertyToColumnMapping*)propertyToColumnMappingForPropertyName:(NSString*)propertyName{
    return _propertyNameDic[propertyName];
}

-(PropertyToColumnMapping*)propertyToColumnMappingForColumnName:(NSString*)columnName{
    return _sqlColumnNameDic[columnName];
}


@end
