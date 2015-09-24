#include "ruby/ruby.h"
#include "appsignal_extension.h"

static VALUE start(VALUE self) {
  appsignal_start();

  return Qnil;
}

static VALUE stop_agent(VALUE self) {
  appsignal_stop_agent();

  return Qnil;
}

static VALUE stop_extension(VALUE self) {
  appsignal_stop_extension();

  return Qnil;
}

static VALUE start_transaction(VALUE self, VALUE transaction_id, VALUE namespace) {
  Check_Type(transaction_id, T_STRING);

  return INT2FIX(appsignal_start_transaction(StringValueCStr(transaction_id), StringValueCStr(namespace)));
}

static VALUE start_event(VALUE self, VALUE transaction_index) {
  Check_Type(transaction_index, T_FIXNUM);

  appsignal_start_event(FIX2INT(transaction_index));
  return Qnil;
}

static VALUE finish_event(VALUE self, VALUE transaction_index, VALUE name, VALUE title, VALUE body) {
  Check_Type(transaction_index, T_FIXNUM);
  Check_Type(name, T_STRING);
  Check_Type(title, T_STRING);
  Check_Type(body, T_STRING);

  appsignal_finish_event(
      FIX2INT(transaction_index),
      StringValueCStr(name),
      StringValueCStr(title),
      StringValueCStr(body)
  );
  return Qnil;
}

static VALUE set_transaction_error(VALUE self, VALUE transaction_index, VALUE name, VALUE message) {
  Check_Type(transaction_index, T_FIXNUM);
  Check_Type(name, T_STRING);
  Check_Type(message, T_STRING);

  appsignal_set_transaction_error(
      FIX2INT(transaction_index),
      StringValueCStr(name),
      StringValueCStr(message)
  );
  return Qnil;
}

static VALUE set_transaction_error_data(VALUE self, VALUE transaction_index, VALUE key, VALUE payload) {
  Check_Type(transaction_index, T_FIXNUM);
  Check_Type(key, T_STRING);
  Check_Type(payload, T_STRING);

  appsignal_set_transaction_error_data(
      FIX2INT(transaction_index),
      StringValueCStr(key),
      StringValueCStr(payload)
  );
  return Qnil;
}

static VALUE set_transaction_action(VALUE self, VALUE transaction_index, VALUE action) {
  Check_Type(transaction_index, T_FIXNUM);
  Check_Type(action, T_STRING);

  appsignal_set_transaction_action(
      FIX2INT(transaction_index),
      StringValueCStr(action)
  );
  return Qnil;
}

static VALUE set_transaction_queue_start(VALUE self, VALUE transaction_index, VALUE queue_start) {
  Check_Type(transaction_index, T_FIXNUM);
  Check_Type(queue_start, T_FIXNUM);

  appsignal_set_transaction_queue_start(
      FIX2INT(transaction_index),
      FIX2LONG(queue_start)
  );
  return Qnil;
}

static VALUE set_transaction_metadata(VALUE self, VALUE transaction_index, VALUE key, VALUE value) {
  Check_Type(transaction_index, T_FIXNUM);
  Check_Type(key, T_STRING);
  Check_Type(value, T_STRING);

  appsignal_set_transaction_metadata(
      FIX2INT(transaction_index),
      StringValueCStr(key),
      StringValueCStr(value)
  );
  return Qnil;
}

static VALUE finish_transaction(VALUE self, VALUE transaction_index) {
  Check_Type(transaction_index, T_FIXNUM);

  appsignal_finish_transaction(FIX2INT(transaction_index));
  return Qnil;
}

static VALUE set_gauge(VALUE self, VALUE key, VALUE value) {
  Check_Type(key, T_STRING);
  Check_Type(value, T_FLOAT);

  appsignal_set_gauge(
      StringValueCStr(key),
      NUM2DBL(value)
  );
  return Qnil;
}

static VALUE set_host_gauge(VALUE self, VALUE key, VALUE value) {
  Check_Type(key, T_STRING);
  Check_Type(value, T_FLOAT);

  appsignal_set_host_gauge(
      StringValueCStr(key),
      NUM2DBL(value)
  );
  return Qnil;
}

static VALUE set_process_gauge(VALUE self, VALUE key, VALUE value) {
  Check_Type(key, T_STRING);
  Check_Type(value, T_FLOAT);

  appsignal_set_process_gauge(
      StringValueCStr(key),
      NUM2DBL(value)
  );
  return Qnil;
}

static VALUE increment_counter(VALUE self, VALUE key, VALUE count) {
  Check_Type(key, T_STRING);
  Check_Type(count, T_FIXNUM);

  appsignal_increment_counter(
      StringValueCStr(key),
      FIX2INT(count)
  );
  return Qnil;
}

static VALUE add_distribution_value(VALUE self, VALUE key, VALUE value) {
  Check_Type(key, T_STRING);
  Check_Type(value, T_FLOAT);

  appsignal_add_distribution_value(
      StringValueCStr(key),
      NUM2DBL(value)
  );
  return Qnil;
}

static void track_allocation(rb_event_flag_t flag, VALUE arg1, VALUE arg2, ID arg3, VALUE arg4) {
  appsignal_track_allocation();
}

static void track_gc_start(rb_event_flag_t flag, VALUE arg1, VALUE arg2, ID arg3, VALUE arg4) {
  appsignal_track_gc_start();
}

static void track_gc_end(rb_event_flag_t flag, VALUE arg1, VALUE arg2, ID arg3, VALUE arg4) {
  appsignal_track_gc_end();
}

static void install_event_hooks() {
  // These event hooks are only available on Ruby 2.1 and 2.2
  #if defined(RUBY_INTERNAL_EVENT_NEWOBJ)
  rb_add_event_hook(
      track_allocation,
      RUBY_INTERNAL_EVENT_NEWOBJ,
      Qnil
  );
  #endif
  #if defined(RUBY_INTERNAL_EVENT_GC_START)
  rb_add_event_hook(
      track_gc_start,
      RUBY_INTERNAL_EVENT_GC_START,
      Qnil
  );
  #endif
  #if defined(RUBY_INTERNAL_EVENT_GC_END_SWEEP)
  // Ruby 2.1
  rb_add_event_hook(
      track_gc_end,
      RUBY_INTERNAL_EVENT_GC_END_SWEEP,
      Qnil
  );
  #endif
  #if defined(RUBY_INTERNAL_EVENT_GC_END)
  // Ruby 2.2
  rb_add_event_hook(
      track_gc_end,
      RUBY_INTERNAL_EVENT_GC_END,
      Qnil
  );
  #endif
}

void Init_appsignal_extension(void) {
  VALUE Appsignal = rb_define_module("Appsignal");
  VALUE Extension = rb_define_class_under(Appsignal, "Extension", rb_cObject);

  // Transaction monitoring
  rb_define_singleton_method(Extension, "start",                       start,                       0);
  rb_define_singleton_method(Extension, "stop_agent",                  stop_agent,                  0);
  rb_define_singleton_method(Extension, "stop_extension",              stop_extension,              0);
  rb_define_singleton_method(Extension, "start_transaction",           start_transaction,           2);
  rb_define_singleton_method(Extension, "start_event",                 start_event,                 1);
  rb_define_singleton_method(Extension, "finish_event",                finish_event,                4);
  rb_define_singleton_method(Extension, "set_transaction_error",       set_transaction_error,       3);
  rb_define_singleton_method(Extension, "set_transaction_error_data",  set_transaction_error_data,  3);
  rb_define_singleton_method(Extension, "set_transaction_action",      set_transaction_action,      2);
  rb_define_singleton_method(Extension, "set_transaction_queue_start", set_transaction_queue_start, 2);
  rb_define_singleton_method(Extension, "set_transaction_metadata",    set_transaction_metadata,    3);
  rb_define_singleton_method(Extension, "finish_transaction",          finish_transaction,          1);

  // Metrics
  rb_define_singleton_method(Extension, "set_gauge",                   set_gauge,                   2);
  rb_define_singleton_method(Extension, "set_host_gauge",              set_host_gauge,              2);
  rb_define_singleton_method(Extension, "set_process_gauge",           set_process_gauge,           2);
  rb_define_singleton_method(Extension, "increment_counter",           increment_counter,           2);
  rb_define_singleton_method(Extension, "add_distribution_value",      add_distribution_value,      2);

  // Event hooks
  install_event_hooks();
}
