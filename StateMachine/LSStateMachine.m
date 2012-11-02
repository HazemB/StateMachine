#import "LSStateMachine.h"
#import "LSEvent.h"
#import "LSTransition.h"
#import <objc/runtime.h>

void * LSStateMachineDefinitionKey = &LSStateMachineDefinitionKey;

@interface LSStateMachine ()
- (LSEvent *)eventWithName:(NSString *)name;
@end

@interface LSStateMachine ()
@property (nonatomic, strong) NSMutableSet *mutableStates;
@property (nonatomic, strong) NSMutableSet *mutableEvents;
@end
@implementation LSStateMachine
- (id)init {
    self = [super init];
    if (self) {
        _mutableStates = [[NSMutableSet alloc] init];
        _mutableEvents = [[NSMutableSet alloc] init];
    }
    return self;
}
- (void)addState:(NSString *)state {
    [self.mutableStates addObject:state];
    if (!self.initialState) {
        self.initialState = state;
    }
}

- (void)when:(NSString *)eventName transitionFrom:(NSString *)from to:(NSString *)to; {
    LSEvent *event = [self eventWithName:eventName];
    LSTransition *transition = [LSTransition transitionFrom:from to:to];
    if (!event) {
        event = [LSEvent eventWithName:eventName transitions:[NSSet setWithObject:transition]];
    } else {
        [self.mutableEvents removeObject:event];
        event = [event addTransition:transition];
    }
    [self.mutableEvents addObject:event];
}

- (NSString *)nextStateFrom:(NSString *)from forEvent:(NSString *)eventName {
    LSEvent *event = [self eventWithName:eventName];
    for (LSTransition *transition in event.transitions) {
        if ([transition.from isEqualToString:from]) {
            return transition.to;
        }
    }
    return nil;
}

- (void)before:(NSString *)eventName do:(LSStateMachineTransitionCallback)callback {
    LSEvent *oldEvent = [self eventWithName:eventName];
    [self.mutableEvents removeObject:oldEvent];
    LSEvent *newEvent = [oldEvent addBeforeCallback:callback];
    [self.mutableEvents addObject:newEvent];
}

- (void)after:(NSString *)eventName do:(LSStateMachineTransitionCallback)callback {
    LSEvent *oldEvent = [self eventWithName:eventName];
    [self.mutableEvents removeObject:oldEvent];
    LSEvent *newEvent = [oldEvent addAfterCallback:callback];
    [self.mutableEvents addObject:newEvent];
}

- (NSSet *)states {
    return [NSSet setWithSet:self.mutableStates];
}

- (NSSet *)events {
    return [NSSet setWithSet:self.mutableEvents];
}

- (void)setInitialState:(NSString *)defaultState {
    [self willChangeValueForKey:@"initialState"];
    _initialState = defaultState;
    [self.mutableStates addObject:defaultState];
    [self didChangeValueForKey:@"initialState"];
}

- (LSEvent *)eventWithName:(NSString *)name {
    for (LSEvent *event in self.events) {
        if ([event.name isEqualToString:name])
            return event;
    }
    return nil;
}

@end

BOOL LSStateMachineTriggerEvent(id self, SEL _cmd) {
    NSString *currentState = [self performSelector:@selector(state)];
    LSStateMachine *sm = [[self class] performSelector:@selector(stateMachine)];
    NSString *eventName = NSStringFromSelector(_cmd);
    NSString *nextState = [sm nextStateFrom:currentState forEvent:eventName];
    if (nextState) {
        LSEvent *event = [sm eventWithName:eventName];
        NSArray *beforeCallbacks = event.beforeCallbacks;
        for (void(^beforeCallback)(id) in beforeCallbacks) {
            beforeCallback(self);
        }
        [self performSelector:@selector(setState:) withObject:nextState];
        
        NSArray *afterCallbacks = event.afterCallbacks;
        for (LSStateMachineTransitionCallback afterCallback in afterCallbacks) {
            afterCallback(self);
        }
        return YES;
    } else {
        return NO;
    }
}

void LSStateMachineInitializeInstance(id self, SEL _cmd) {
    LSStateMachine *sm = [[self class] performSelector:@selector(stateMachine)];
    [self performSelector:@selector(setState:) withObject:[sm initialState]];
}

BOOL LSStateMachineCheckState(id self, SEL _cmd) {
    NSString *currentState = [self performSelector:@selector(state)];
    NSString *query = [[NSStringFromSelector(_cmd) stringByReplacingOccurrencesOfString:@"is" withString:@""] lowercaseString];
    return [query isEqualToString:currentState];
}

BOOL LSStateMachineCheckCanTransition(id self, SEL _cmd) {
    LSStateMachine *sm = [[self class] performSelector:@selector(stateMachine)];
    NSString *currentState = [self performSelector:@selector(state)];
    NSString *query = [[NSStringFromSelector(_cmd) stringByReplacingOccurrencesOfString:@"can" withString:@""] lowercaseString];
    NSString *nextState = [sm nextStateFrom:currentState forEvent:query];
    return nextState != nil;
}

void LSStateMachineInitializeClass(Class klass) {
    LSStateMachine *sm = [klass performSelector:@selector(stateMachine)];
    for (LSEvent *event in sm.events) {
        class_addMethod(klass, NSSelectorFromString(event.name), (IMP) LSStateMachineTriggerEvent, "i@:");
        
        NSString *transitionQueryMethodName = [NSString stringWithFormat:@"can%@", [event.name capitalizedString]];
        class_addMethod(klass, NSSelectorFromString(transitionQueryMethodName), (IMP) LSStateMachineCheckCanTransition, "i@:");
    }
    
    for (NSString *state in sm.states) {
        NSString *queryMethodName = [NSString stringWithFormat:@"is%@", [state capitalizedString]];
        class_addMethod(klass, NSSelectorFromString(queryMethodName), (IMP) LSStateMachineCheckState, "i@:");
    }
    class_addMethod(klass, @selector(initializeStateMachine), (IMP) LSStateMachineInitializeInstance, "v@:");
}

LSStateMachine * LSStateMachineSetDefinitionForClass(Class klass,void(^definition)(LSStateMachine *)) {
    LSStateMachine *sm = (LSStateMachine *)objc_getAssociatedObject(klass, &LSStateMachineDefinitionKey);
    if (!sm) {
        sm = [[LSStateMachine alloc] init];
        objc_setAssociatedObject (
                                  klass,
                                  &LSStateMachineDefinitionKey,
                                  sm,
                                  OBJC_ASSOCIATION_RETAIN
                                  );
        definition(sm);
    }
    return sm;

}
