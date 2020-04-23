module source_date_epoch;

static immutable Date = __DATE__;
static immutable Time = __TIME__;
static immutable TimeStamp = __TIMESTAMP__;

pragma(msg, Date);
pragma(msg, Time);
pragma(msg, TimeStamp);
