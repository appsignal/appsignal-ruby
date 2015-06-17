#include<ruby.h>
#include<appsignal_extension.h>

static VALUE start(VALUE self) {
  appsignal_start();

  return Qnil;
}

static VALUE stop(VALUE self) {
  appsignal_stop();

  return Qnil;
}

static VALUE start_transaction(VALUE self, VALUE transaction_id) {
  Check_Type(transaction_id, T_STRING);

  appsignal_start_transaction(StringValueCStr(transaction_id));
  return Qnil;
}

static VALUE start_event(VALUE self, VALUE transaction_id) {
  Check_Type(transaction_id, T_STRING);

  appsignal_start_event(StringValueCStr(transaction_id));
  return Qnil;
}

static VALUE finish_event(VALUE self, VALUE transaction_id, VALUE name, VALUE title, VALUE body) {
  Check_Type(transaction_id, T_STRING);
  Check_Type(name, T_STRING);
  Check_Type(title, T_STRING);
  Check_Type(body, T_STRING);

  appsignal_finish_event(
      StringValueCStr(transaction_id),
      StringValueCStr(name),
      StringValueCStr(title),
      StringValueCStr(body)
  );
  return Qnil;
}

static VALUE set_transaction_error(VALUE self, VALUE transaction_id, VALUE name, VALUE message) {
  Check_Type(transaction_id, T_STRING);
  Check_Type(name, T_STRING);
  Check_Type(message, T_STRING);

  appsignal_set_transaction_error(
      StringValueCStr(transaction_id),
      StringValueCStr(name),
      StringValueCStr(message)
  );
  return Qnil;
}

static VALUE set_transaction_error_data(VALUE self, VALUE transaction_id, VALUE key, VALUE payload) {
  Check_Type(transaction_id, T_STRING);
  Check_Type(key, T_STRING);
  Check_Type(payload, T_STRING);

  appsignal_set_transaction_error_data(
      StringValueCStr(transaction_id),
      StringValueCStr(key),
      StringValueCStr(payload)
  );
  return Qnil;
}

static VALUE set_transaction_basedata(VALUE self, VALUE transaction_id, VALUE namespace, VALUE action, VALUE queue_start) {
  Check_Type(transaction_id, T_STRING);
  Check_Type(namespace, T_STRING);
  Check_Type(action, T_STRING);
  Check_Type(queue_start, T_FIXNUM);

  appsignal_set_transaction_basedata(
      StringValueCStr(transaction_id),
      StringValueCStr(namespace),
      StringValueCStr(action),
      FIX2LONG(queue_start)
  );
  return Qnil;
}

static VALUE set_transaction_metadata(VALUE self, VALUE transaction_id, VALUE key, VALUE value) {
  Check_Type(transaction_id, T_STRING);
  Check_Type(key, T_STRING);
  Check_Type(value, T_STRING);

  appsignal_set_transaction_metadata(
      StringValueCStr(transaction_id),
      StringValueCStr(key),
      StringValueCStr(value)
  );
  return Qnil;
}

static VALUE finish_transaction(VALUE self, VALUE transaction_id) {
  Check_Type(transaction_id, T_STRING);

  appsignal_finish_transaction(StringValueCStr(transaction_id));
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

void Init_appsignal_extension(void) {
  VALUE Appsignal = rb_define_module("Appsignal");
  VALUE Extension = rb_define_class_under(Appsignal, "Extension", rb_cObject);

  // Transaction monitoring
  rb_define_singleton_method(Extension, "start",                      start,                      0);
  rb_define_singleton_method(Extension, "stop",                       stop,                       0);
  rb_define_singleton_method(Extension, "start_transaction",          start_transaction,          1);
  rb_define_singleton_method(Extension, "start_event",                start_event,                1);
  rb_define_singleton_method(Extension, "finish_event",               finish_event,               4);
  rb_define_singleton_method(Extension, "set_transaction_error",      set_transaction_error,      3);
  rb_define_singleton_method(Extension, "set_transaction_error_data", set_transaction_error_data, 3);
  rb_define_singleton_method(Extension, "set_transaction_basedata",   set_transaction_basedata,   4);
  rb_define_singleton_method(Extension, "set_transaction_metadata",   set_transaction_metadata,   3);
  rb_define_singleton_method(Extension, "finish_transaction",         finish_transaction,         1);

  // Metrics
  rb_define_singleton_method(Extension, "set_gauge",                  set_gauge,                  2);
  rb_define_singleton_method(Extension, "set_host_gauge",             set_host_gauge,             2);
  rb_define_singleton_method(Extension, "set_process_gauge",          set_process_gauge,          2);
  rb_define_singleton_method(Extension, "increment_counter",          increment_counter,          2);
  rb_define_singleton_method(Extension, "add_distribution_value",     add_distribution_value,     2);
}
