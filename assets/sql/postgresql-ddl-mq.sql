DROP TABLE IF EXISTS statemachine_transitions_configuration;


CREATE TABLE statemachine_transitions_configuration (
    id serial,
    machine VARCHAR NOT NULL,
    state_from VARCHAR NOT NULL,
    state_to VARCHAR NULL,
    backoff VARCHAR NOT NULL DEFAULT '3600',
    throttle_interval INT NULL,
    throttle_key VARCHAR NULL,
    stop_after_transition bool DEFAULT false,
    CONSTRAINT fk_sm_t_c_sf_sm_s_m_s FOREIGN KEY (machine, state_from, state_to) REFERENCES statemachine_transitions (machine, state_from, state_to) ON UPDATE CASCADE,
    CONSTRAINT c_sm_t_c_b CHECK(backoff ~* '^[\d]+((-)[\d]+)+$'),
    CONSTRAINT u_sm_t_c_m_st_sf UNIQUE (machine, state_to, state_from),
    PRIMARY KEY  (id)
);


COMMENT ON COLUMN statemachine_transitions_configuration.id IS '
An artificial key is needed since {machine,state_from,state_to} must be able
to contain a null value for state_to and can therefore not be a primary key';

COMMENT ON COLUMN statemachine_transitions_configuration.state_to IS '
If this field is null, it indicates that this specific configuration applies to
all transitions from the state_from field. This allows us to configure a "blanket
configuration" in case the statemachine has tried all transitions but all the rules
denied the transition. In that case, we cannot guess which specific 
configuration to adhere to and we provide the "blanket configuration"';

COMMENT ON COLUMN statemachine_transitions_configuration.backoff IS '
Each time a transition from a state is performed and the rule disallows it, 
the message should be requeued with a delay according to the backoff. Backoff is
in the format /^[\d]+((-)[\d]+)+$/ and specfies seconds eg: "300-3600-21600-86400".
This would mean that after the first try, wait 300 seconds. after that, 3600 seconds etc..
This also implies that the number of retries should be encoded in the message on the mq.
Backoff will mostly be relevant for states that need to wait for a certain time or 
can only proceed on a certain day.';

COMMENT ON COLUMN statemachine_transitions_configuration.throttle_interval IS '
Certain transitions might only be allowed to take place every x seconds.
A throttle interval operates on every transition that is configured by the throttle key
and should make sure only 1 transition for that state is allowed/scheduled on every
x seconds by the scheduling algorithm for the queue.';

COMMENT ON COLUMN statemachine_transitions_configuration.throttle_key IS '
Throttled transitions are coupled to a key that can be used as an identifier to the
backend that calculates throttling. The key name should be unique for the transition.
When multiple transitions (from multiple states) share the same throttle key then the behaviour will be
that only 1 of these transitions will be allowed to run every x seconds.
This also means that depending on which state wants to transition first is the first
to be scheduled, the others follow in the order in which they want to transition.';

COMMENT ON COLUMN statemachine_transitions_configuration.stop_after_transition IS '
The queue wants to make as much transitions on the statemachine as possible by default.
This field indicates that a statemachine should not automatically transition further after this transition.
This allows a user to do manual inspection and a manual transition for the next step, possibly
requeueing the message.';

COMMENT ON TABLE statemachine_transitions_configuration IS '
The configuration for the transitions of statemachines is defined here.
It is used for a message queueing systems, where we can regulate the automated processing
of messages that contain a unique definition of a statemachine: {machine,id}.
Defaults should be used in the application code, so if an entry is not here for a state, a sensible default is used.
Keep in mind that some configurations will not make sense, eg: specifying
a throttle on a specific state_from/state_to when there are multiple possible 
exit transitions from a state. In case the throttle step rule allows the transition,
the message will be scheduled. When the time arrives, it is not guaranteed that another
rule will not run first and then allow that specific transition.
In other words:
- do not use throttling on a "blanket configuration"
- do not use throttling on a state that has multiple exit transitions
- throttling only makes sense for a state that has 1 exit transition
- backoff only makes sense for a state that has 1 exit transition';


