#include "ruby/ruby.h"
#include "ruby/encoding.h"
#include "appsignal.h"

static inline appsignal_string_t make_appsignal_string(VALUE str) {
  return (appsignal_string_t) {
    .len = RSTRING_LEN(str),
    .buf = RSTRING_PTR(str)
  };
}

static inline VALUE make_ruby_string(appsignal_string_t string) {
  VALUE str = rb_str_new(string.buf, string.len);
  rb_enc_associate(str, rb_utf8_encoding());
  return str;
}

VALUE Appsignal;
VALUE Extension;
VALUE ExtTransaction;

static VALUE start(VALUE self) {
  appsignal_start();

  return Qnil;
}

static VALUE stop(VALUE self) {
  appsignal_stop();

  return Qnil;
}

static VALUE get_server_state(VALUE self, VALUE key) {
  appsignal_string_t string;

  Check_Type(key, T_STRING);

  string = appsignal_get_server_state(make_appsignal_string(key));
  if (string.len > 0) {
    return make_ruby_string(string);
  } else {
    return Qnil;
  }
}

static VALUE start_transaction(VALUE self, VALUE transaction_id, VALUE namespace) {
  appsignal_transaction_t* transaction;

  Check_Type(transaction_id, T_STRING);
  Check_Type(namespace, T_STRING);

  transaction = appsignal_start_transaction(
      make_appsignal_string(transaction_id),
      make_appsignal_string(namespace)
  );

  if (transaction) {
    return Data_Wrap_Struct(ExtTransaction, NULL, appsignal_free_transaction, transaction);
  } else {
    return Qnil;
  }
}

static VALUE start_event(VALUE self) {
  appsignal_transaction_t* transaction;

  Data_Get_Struct(self, appsignal_transaction_t, transaction);

  appsignal_start_event(transaction);

  return Qnil;
}

static VALUE finish_event(VALUE self, VALUE name, VALUE title, VALUE body, VALUE body_format) {
  appsignal_transaction_t* transaction;

  Check_Type(name, T_STRING);
  Check_Type(title, T_STRING);
  Check_Type(body, T_STRING);
  Check_Type(body_format, T_FIXNUM);
  Data_Get_Struct(self, appsignal_transaction_t, transaction);

  appsignal_finish_event(
      transaction,
      make_appsignal_string(name),
      make_appsignal_string(title),
      make_appsignal_string(body),
      FIX2INT(body_format)
  );
  return Qnil;
}

static VALUE record_event(VALUE self, VALUE name, VALUE title, VALUE body, VALUE duration, VALUE body_format) {
  appsignal_transaction_t* transaction;
  int duration_type;

  Check_Type(name, T_STRING);
  Check_Type(title, T_STRING);
  Check_Type(body, T_STRING);
  duration_type = TYPE(duration);
  if (duration_type != T_FIXNUM && duration_type != T_BIGNUM) {
      rb_raise(rb_eTypeError, "duration should be a Fixnum or Bignum");
  }
  Check_Type(body_format, T_FIXNUM);
  Data_Get_Struct(self, appsignal_transaction_t, transaction);

  appsignal_record_event(
      transaction,
      make_appsignal_string(name),
      make_appsignal_string(title),
      make_appsignal_string(body),
      FIX2INT(body_format),
      NUM2LONG(duration)
  );
  return Qnil;
}

static VALUE set_transaction_error(VALUE self, VALUE name, VALUE message, VALUE backtrace) {
  appsignal_transaction_t* transaction;

  Check_Type(name, T_STRING);
  Check_Type(message, T_STRING);
  Check_Type(backtrace, T_STRING);
  Data_Get_Struct(self, appsignal_transaction_t, transaction);

  appsignal_set_transaction_error(
      transaction,
      make_appsignal_string(name),
      make_appsignal_string(message),
      make_appsignal_string(backtrace)
  );
  return Qnil;
}

static VALUE set_transaction_sample_data(VALUE self, VALUE key, VALUE payload) {
  appsignal_transaction_t* transaction;

  Check_Type(key, T_STRING);
  Check_Type(payload, T_STRING);
  Data_Get_Struct(self, appsignal_transaction_t, transaction);

  appsignal_set_transaction_sample_data(
      transaction,
      make_appsignal_string(key),
      make_appsignal_string(payload)
  );
  return Qnil;
}

static VALUE set_transaction_action(VALUE self, VALUE action) {
  appsignal_transaction_t* transaction;

  Check_Type(action, T_STRING);
  Data_Get_Struct(self, appsignal_transaction_t, transaction);

  appsignal_set_transaction_action(
      transaction,
      make_appsignal_string(action)
  );
  return Qnil;
}

static VALUE set_transaction_queue_start(VALUE self, VALUE queue_start) {
  appsignal_transaction_t* transaction;
  int queue_start_type;

  queue_start_type = TYPE(queue_start);
  if (queue_start_type != T_FIXNUM && queue_start_type != T_BIGNUM) {
      rb_raise(rb_eTypeError, "queue_start should be a Fixnum or Bignum");
  }

  Data_Get_Struct(self, appsignal_transaction_t, transaction);

  appsignal_set_transaction_queue_start(
      transaction,
      NUM2LONG(queue_start)
  );
  return Qnil;
}

static VALUE set_transaction_metadata(VALUE self, VALUE key, VALUE value) {
  appsignal_transaction_t* transaction;

  Check_Type(key, T_STRING);
  Check_Type(value, T_STRING);
  Data_Get_Struct(self, appsignal_transaction_t, transaction);

  appsignal_set_transaction_metadata(
      transaction,
      make_appsignal_string(key),
      make_appsignal_string(value)
  );
  return Qnil;
}

static VALUE finish_transaction(VALUE self) {
  appsignal_transaction_t* transaction;
  int sample;

  Data_Get_Struct(self, appsignal_transaction_t, transaction);

  sample = appsignal_finish_transaction(transaction);
  return sample == 1 ? Qtrue : Qfalse;
}

static VALUE complete_transaction(VALUE self) {
  appsignal_transaction_t* transaction;

  Data_Get_Struct(self, appsignal_transaction_t, transaction);

  appsignal_complete_transaction(transaction);
  return Qnil;
}

static VALUE set_gauge(VALUE self, VALUE key, VALUE value) {
  Check_Type(key, T_STRING);
  Check_Type(value, T_FLOAT);

  appsignal_set_gauge(
      make_appsignal_string(key),
      NUM2DBL(value)
  );
  return Qnil;
}

static VALUE set_host_gauge(VALUE self, VALUE key, VALUE value) {
  Check_Type(key, T_STRING);
  Check_Type(value, T_FLOAT);

  appsignal_set_host_gauge(
      make_appsignal_string(key),
      NUM2DBL(value)
  );
  return Qnil;
}

static VALUE set_process_gauge(VALUE self, VALUE key, VALUE value) {
  Check_Type(key, T_STRING);
  Check_Type(value, T_FLOAT);

  appsignal_set_process_gauge(
      make_appsignal_string(key),
      NUM2DBL(value)
  );
  return Qnil;
}

static VALUE increment_counter(VALUE self, VALUE key, VALUE count) {
  Check_Type(key, T_STRING);
  Check_Type(count, T_FIXNUM);

  appsignal_increment_counter(
      make_appsignal_string(key),
      FIX2INT(count)
  );
  return Qnil;
}

static VALUE add_distribution_value(VALUE self, VALUE key, VALUE value) {
  Check_Type(key, T_STRING);
  Check_Type(value, T_FLOAT);

  appsignal_add_distribution_value(
      make_appsignal_string(key),
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

static VALUE install_allocation_event_hook() {
  // This event hook is only available on Ruby 2.1 and 2.2
  #if defined(RUBY_INTERNAL_EVENT_NEWOBJ)
  rb_add_event_hook(
      track_allocation,
      RUBY_INTERNAL_EVENT_NEWOBJ,
      Qnil
  );
  #endif

  return Qnil;
}

static VALUE install_gc_event_hooks() {
  // These event hooks are only available on Ruby 2.1 and 2.2
  #if defined(RUBY_INTERNAL_EVENT_GC_START)
  rb_add_event_hook(
      track_gc_start,
      RUBY_INTERNAL_EVENT_GC_START,
      Qnil
  );
  #endif
  #if defined(RUBY_INTERNAL_EVENT_GC_END_MARK)
  rb_add_event_hook(
      track_gc_end,
      RUBY_INTERNAL_EVENT_GC_END_MARK,
      Qnil
  );
  #endif

  return Qnil;
}

void Init_appsignal_extension(void) {
  Appsignal = rb_define_module("Appsignal");
  Extension = rb_define_class_under(Appsignal, "Extension", rb_cObject);
  ExtTransaction = rb_define_class_under(Extension, "ExtTransaction", rb_cObject);

  // Starting and stopping
  rb_define_singleton_method(Extension, "start", start, 0);
  rb_define_singleton_method(Extension, "stop",  stop,  0);

  // Server state
  rb_define_singleton_method(Extension, "get_server_state", get_server_state, 1);

  // Start transaction
  rb_define_singleton_method(Extension, "start_transaction", start_transaction, 2);

  // Transaction instance methods
  rb_define_method(ExtTransaction, "start_event",     start_event,                 0);
  rb_define_method(ExtTransaction, "finish_event",    finish_event,                4);
  rb_define_method(ExtTransaction, "record_event",    record_event,                5);
  rb_define_method(ExtTransaction, "set_error",       set_transaction_error,       3);
  rb_define_method(ExtTransaction, "set_sample_data", set_transaction_sample_data, 2);
  rb_define_method(ExtTransaction, "set_action",      set_transaction_action,      1);
  rb_define_method(ExtTransaction, "set_queue_start", set_transaction_queue_start, 1);
  rb_define_method(ExtTransaction, "set_metadata",    set_transaction_metadata,    2);
  rb_define_method(ExtTransaction, "finish",          finish_transaction,          0);
  rb_define_method(ExtTransaction, "complete",        complete_transaction,        0);

  // Event hook installation
  rb_define_singleton_method(Extension, "install_allocation_event_hook", install_allocation_event_hook, 0);
  rb_define_singleton_method(Extension, "install_gc_event_hooks",        install_gc_event_hooks,        0);

  // Metrics
  rb_define_singleton_method(Extension, "set_gauge",              set_gauge,              2);
  rb_define_singleton_method(Extension, "set_host_gauge",         set_host_gauge,         2);
  rb_define_singleton_method(Extension, "set_process_gauge",      set_process_gauge,      2);
  rb_define_singleton_method(Extension, "increment_counter",      increment_counter,      2);
  rb_define_singleton_method(Extension, "add_distribution_value", add_distribution_value, 2);
}
