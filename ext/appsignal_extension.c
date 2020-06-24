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
VALUE Transaction;
VALUE Data;

static VALUE start(VALUE self) {
  appsignal_start();

  return Qnil;
}

static VALUE stop(VALUE self) {
  appsignal_stop();

  return Qnil;
}

static VALUE diagnose(VALUE self) {
  return make_ruby_string(appsignal_diagnose());
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

static VALUE start_transaction(VALUE self, VALUE transaction_id, VALUE namespace, VALUE gc_duration_ms) {
  appsignal_transaction_t* transaction;

  Check_Type(transaction_id, T_STRING);
  Check_Type(namespace, T_STRING);
  Check_Type(gc_duration_ms, T_FIXNUM);

  transaction = appsignal_start_transaction(
      make_appsignal_string(transaction_id),
      make_appsignal_string(namespace),
      NUM2LONG(gc_duration_ms)
  );

  if (transaction) {
    return Data_Wrap_Struct(Transaction, NULL, appsignal_free_transaction, transaction);
  } else {
    return Qnil;
  }
}

static VALUE start_event(VALUE self, VALUE gc_duration_ms) {
  appsignal_transaction_t* transaction;

  Check_Type(gc_duration_ms, T_FIXNUM);

  Data_Get_Struct(self, appsignal_transaction_t, transaction);

  appsignal_start_event(transaction, NUM2LONG(gc_duration_ms));

  return Qnil;
}

static VALUE finish_event(VALUE self, VALUE name, VALUE title, VALUE body, VALUE body_format, VALUE gc_duration_ms) {
  appsignal_transaction_t* transaction;
  appsignal_data_t* body_data;
  int body_type;

  Check_Type(name, T_STRING);
  Check_Type(title, T_STRING);
  Check_Type(body_format, T_FIXNUM);

  Data_Get_Struct(self, appsignal_transaction_t, transaction);

  body_type = TYPE(body);
  if (body_type == T_STRING) {
    appsignal_finish_event(
        transaction,
        make_appsignal_string(name),
        make_appsignal_string(title),
        make_appsignal_string(body),
        FIX2INT(body_format),
        FIX2LONG(gc_duration_ms)
    );
  } else if (body_type == RUBY_T_DATA) {
    Data_Get_Struct(body, appsignal_data_t, body_data);
    appsignal_finish_event_data(
        transaction,
        make_appsignal_string(name),
        make_appsignal_string(title),
        body_data,
        FIX2INT(body_format),
        FIX2LONG(gc_duration_ms)
    );
  } else {
      rb_raise(rb_eTypeError, "body should be a String or Appsignal::Extension::Data");
  }

  return Qnil;
}

static VALUE record_event(VALUE self, VALUE name, VALUE title, VALUE body, VALUE body_format, VALUE duration, VALUE gc_duration_ms) {
  appsignal_transaction_t* transaction;
  appsignal_data_t* body_data;
  int body_type;
  int duration_type;

  Check_Type(name, T_STRING);
  Check_Type(title, T_STRING);
  duration_type = TYPE(duration);
  if (duration_type != T_FIXNUM && duration_type != T_BIGNUM) {
      rb_raise(rb_eTypeError, "duration should be an Integer");
  }
  Check_Type(body_format, T_FIXNUM);

  Data_Get_Struct(self, appsignal_transaction_t, transaction);

  body_type = TYPE(body);
  if (body_type == T_STRING) {
    appsignal_record_event(
        transaction,
        make_appsignal_string(name),
        make_appsignal_string(title),
        make_appsignal_string(body),
        FIX2INT(body_format),
        NUM2LONG(duration),
        NUM2LONG(gc_duration_ms)
    );
  } else if (body_type == RUBY_T_DATA) {
    Data_Get_Struct(body, appsignal_data_t, body_data);
    appsignal_record_event_data(
        transaction,
        make_appsignal_string(name),
        make_appsignal_string(title),
        body_data,
        FIX2INT(body_format),
        NUM2LONG(duration),
        NUM2LONG(gc_duration_ms)
    );
  } else {
      rb_raise(rb_eTypeError, "body should be a String or Appsignal::Extension::Data");
  }

  return Qnil;
}

static VALUE set_transaction_error(VALUE self, VALUE name, VALUE message, VALUE backtrace) {
  appsignal_transaction_t* transaction;
  appsignal_data_t* backtrace_data;

  Check_Type(name, T_STRING);
  Check_Type(message, T_STRING);
  Check_Type(backtrace, RUBY_T_DATA);

  Data_Get_Struct(self, appsignal_transaction_t, transaction);
  Data_Get_Struct(backtrace, appsignal_data_t, backtrace_data);

  appsignal_set_transaction_error(
      transaction,
      make_appsignal_string(name),
      make_appsignal_string(message),
      backtrace_data
  );
  return Qnil;
}

static VALUE set_transaction_sample_data(VALUE self, VALUE key, VALUE payload) {
  appsignal_transaction_t* transaction;
  appsignal_data_t* payload_data;

  Check_Type(key, T_STRING);
  Check_Type(payload, RUBY_T_DATA);

  Data_Get_Struct(self, appsignal_transaction_t, transaction);
  Data_Get_Struct(payload, appsignal_data_t, payload_data);

  appsignal_set_transaction_sample_data(
      transaction,
      make_appsignal_string(key),
      payload_data
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

static VALUE set_transaction_namespace(VALUE self, VALUE namespace) {
  appsignal_transaction_t* transaction;

  Check_Type(namespace, T_STRING);
  Data_Get_Struct(self, appsignal_transaction_t, transaction);

  appsignal_set_transaction_namespace(
      transaction,
      make_appsignal_string(namespace)
  );
  return Qnil;
}

static VALUE set_transaction_queue_start(VALUE self, VALUE queue_start) {
  appsignal_transaction_t* transaction;
  int queue_start_type;

  queue_start_type = TYPE(queue_start);
  if (queue_start_type != T_FIXNUM && queue_start_type != T_BIGNUM) {
      rb_raise(rb_eTypeError, "queue_start should be an Integer");
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

static VALUE finish_transaction(VALUE self, VALUE gc_duration_ms) {
  appsignal_transaction_t* transaction;
  int sample;

  Check_Type(gc_duration_ms, T_FIXNUM);
  Data_Get_Struct(self, appsignal_transaction_t, transaction);

  sample = appsignal_finish_transaction(transaction, NUM2LONG(gc_duration_ms));
  return sample == 1 ? Qtrue : Qfalse;
}

static VALUE complete_transaction(VALUE self) {
  appsignal_transaction_t* transaction;

  Data_Get_Struct(self, appsignal_transaction_t, transaction);

  appsignal_complete_transaction(transaction);
  return Qnil;
}

static VALUE transaction_to_json(VALUE self) {
  appsignal_transaction_t* transaction;
  appsignal_string_t json;

  Data_Get_Struct(self, appsignal_transaction_t, transaction);

  json = appsignal_transaction_to_json(transaction);

  if (json.len == 0) {
    return Qnil;
  } else {
    return make_ruby_string(json);
  }
}

static VALUE data_map_new(VALUE self) {
  appsignal_data_t* data;

  data = appsignal_data_map_new();

  if (data) {
    return Data_Wrap_Struct(Data, NULL, appsignal_free_data, data);
  } else {
    return Qnil;
  }
}

static VALUE data_array_new(VALUE self) {
  appsignal_data_t* data;

  data = appsignal_data_array_new();

  if (data) {
    return Data_Wrap_Struct(Data, NULL, appsignal_free_data, data);
  } else {
    return Qnil;
  }
}

static VALUE data_set_string(VALUE self, VALUE key, VALUE value) {
  appsignal_data_t* data;

  Check_Type(key, T_STRING);
  Check_Type(value, T_STRING);

  Data_Get_Struct(self, appsignal_data_t, data);

  appsignal_data_map_set_string(
    data,
    make_appsignal_string(key),
    make_appsignal_string(value)
  );

  return Qnil;
}

static VALUE data_set_integer(VALUE self, VALUE key, VALUE value) {
  appsignal_data_t* data;
  VALUE value_type = TYPE(value);

  Check_Type(key, T_STRING);
  if (value_type != T_FIXNUM && value_type != T_BIGNUM) {
    rb_raise(rb_eTypeError, "wrong argument type %s (expected Integer)", rb_obj_classname(value));
  }

  Data_Get_Struct(self, appsignal_data_t, data);

  appsignal_data_map_set_integer(
    data,
    make_appsignal_string(key),
    NUM2LONG(value)
  );

  return Qnil;
}

static VALUE data_set_float(VALUE self, VALUE key, VALUE value) {
  appsignal_data_t* data;

  Check_Type(key, T_STRING);
  Check_Type(value, T_FLOAT);

  Data_Get_Struct(self, appsignal_data_t, data);

  appsignal_data_map_set_float(
    data,
    make_appsignal_string(key),
    NUM2DBL(value)
  );

  return Qnil;
}

static VALUE data_set_boolean(VALUE self, VALUE key, VALUE value) {
  appsignal_data_t* data;

  Check_Type(key, T_STRING);

  Data_Get_Struct(self, appsignal_data_t, data);

  appsignal_data_map_set_boolean(
    data,
    make_appsignal_string(key),
    RTEST(value)
  );

  return Qnil;
}

static VALUE data_set_nil(VALUE self, VALUE key) {
  appsignal_data_t* data;

  Check_Type(key, T_STRING);

  Data_Get_Struct(self, appsignal_data_t, data);

  appsignal_data_map_set_null(
    data,
    make_appsignal_string(key)
  );

  return Qnil;
}

static VALUE data_set_data(VALUE self, VALUE key, VALUE value) {
  appsignal_data_t* data;
  appsignal_data_t* value_data;

  Check_Type(key, T_STRING);
  Check_Type(value, RUBY_T_DATA);

  Data_Get_Struct(self, appsignal_data_t, data);
  Data_Get_Struct(value, appsignal_data_t, value_data);

  appsignal_data_map_set_data(
    data,
    make_appsignal_string(key),
    value_data
  );

  return Qnil;
}

static VALUE data_append_string(VALUE self, VALUE value) {
  appsignal_data_t* data;

  Check_Type(value, T_STRING);

  Data_Get_Struct(self, appsignal_data_t, data);

  appsignal_data_array_append_string(
    data,
    make_appsignal_string(value)
  );

  return Qnil;
}

static VALUE data_append_integer(VALUE self, VALUE value) {
  appsignal_data_t* data;
  VALUE value_type = TYPE(value);

  if (value_type != T_FIXNUM && value_type != T_BIGNUM) {
    rb_raise(rb_eTypeError, "wrong argument type %s (expected Integer)", rb_obj_classname(value));
  }

  Data_Get_Struct(self, appsignal_data_t, data);

  appsignal_data_array_append_integer(
    data,
    NUM2LONG(value)
 );

  return Qnil;
}

static VALUE data_append_float(VALUE self, VALUE value) {
  appsignal_data_t* data;

  Check_Type(value, T_FLOAT);

  Data_Get_Struct(self, appsignal_data_t, data);

  appsignal_data_array_append_float(
    data,
    NUM2DBL(value)
 );

  return Qnil;
}

static VALUE data_append_boolean(VALUE self, VALUE value) {
  appsignal_data_t* data;

  Data_Get_Struct(self, appsignal_data_t, data);

  appsignal_data_array_append_boolean(
    data,
    RTEST(value)
 );

  return Qnil;
}

static VALUE data_append_nil(VALUE self, VALUE value) {
  appsignal_data_t* data;

  Data_Get_Struct(self, appsignal_data_t, data);

  appsignal_data_array_append_null(data);

  return Qnil;
}

static VALUE data_append_data(VALUE self, VALUE value) {
  appsignal_data_t* data;
  appsignal_data_t* value_data;

  Check_Type(value, RUBY_T_DATA);

  Data_Get_Struct(self, appsignal_data_t, data);
  Data_Get_Struct(value, appsignal_data_t, value_data);

  appsignal_data_array_append_data(
    data,
    value_data
  );

  return Qnil;
}

static VALUE data_equal(VALUE self, VALUE other) {
  appsignal_data_t* data;
  appsignal_data_t* other_data;

  if (TYPE(other) != RUBY_T_DATA) {
    return Qfalse;
  }

  Data_Get_Struct(self, appsignal_data_t, data);
  Data_Get_Struct(other, appsignal_data_t, other_data);

  if (appsignal_data_equal(data, other_data) == 1) {
    return Qtrue;
  } else {
    return Qfalse;
  }
}

static VALUE data_to_s(VALUE self) {
  appsignal_data_t* data;
  appsignal_string_t json;

  Data_Get_Struct(self, appsignal_data_t, data);

  json = appsignal_data_to_json(data);

  if (json.len == 0) {
    return Qnil;
  } else {
    return make_ruby_string(json);
  }
}

static VALUE set_gauge(VALUE self, VALUE key, VALUE value, VALUE tags) {
  appsignal_data_t* tags_data;

  Check_Type(key, T_STRING);
  Check_Type(value, T_FLOAT);
  Check_Type(tags, RUBY_T_DATA);

  Data_Get_Struct(tags, appsignal_data_t, tags_data);

  appsignal_set_gauge(
      make_appsignal_string(key),
      NUM2DBL(value),
      tags_data
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

static VALUE increment_counter(VALUE self, VALUE key, VALUE count, VALUE tags) {
  appsignal_data_t* tags_data;

  Check_Type(key, T_STRING);
  Check_Type(count, T_FLOAT);
  Check_Type(tags, RUBY_T_DATA);

  Data_Get_Struct(tags, appsignal_data_t, tags_data);

  appsignal_increment_counter(
      make_appsignal_string(key),
      NUM2DBL(count),
      tags_data
  );
  return Qnil;
}

static VALUE add_distribution_value(VALUE self, VALUE key, VALUE value, VALUE tags) {
  appsignal_data_t* tags_data;

  Check_Type(key, T_STRING);
  Check_Type(value, T_FLOAT);
  Check_Type(tags, RUBY_T_DATA);

  Data_Get_Struct(tags, appsignal_data_t, tags_data);

  appsignal_add_distribution_value(
      make_appsignal_string(key),
      NUM2DBL(value),
      tags_data
  );
  return Qnil;
}

static void track_allocation(rb_event_flag_t flag, VALUE arg1, VALUE arg2, ID arg3, VALUE arg4) {
  appsignal_track_allocation();
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

static VALUE running_in_container() {
  return appsignal_running_in_container() == 1 ? Qtrue : Qfalse;
}

static VALUE set_environment_metadata(VALUE self, VALUE key, VALUE value) {
  appsignal_set_environment_metadata(
      make_appsignal_string(key),
      make_appsignal_string(value)
  );
  return Qnil;
}

void Init_appsignal_extension(void) {
  Appsignal = rb_define_module("Appsignal");
  Extension = rb_define_class_under(Appsignal, "Extension", rb_cObject);
  Transaction = rb_define_class_under(Extension, "Transaction", rb_cObject);
  Data = rb_define_class_under(Extension, "Data", rb_cObject);

  // Starting and stopping
  rb_define_singleton_method(Extension, "start",    start,    0);
  rb_define_singleton_method(Extension, "stop",     stop,     0);
  // Diagnostics
  rb_define_singleton_method(Extension, "diagnose", diagnose, 0);

  // Server state
  rb_define_singleton_method(Extension, "get_server_state", get_server_state, 1);

  // Start transaction
  rb_define_singleton_method(Extension, "start_transaction", start_transaction, 3);

  // Transaction instance methods
  rb_define_method(Transaction, "start_event",     start_event,                 1);
  rb_define_method(Transaction, "finish_event",    finish_event,                5);
  rb_define_method(Transaction, "record_event",    record_event,                6);
  rb_define_method(Transaction, "set_error",       set_transaction_error,       3);
  rb_define_method(Transaction, "set_sample_data", set_transaction_sample_data, 2);
  rb_define_method(Transaction, "set_action",      set_transaction_action,      1);
  rb_define_method(Transaction, "set_namespace",   set_transaction_namespace,   1);
  rb_define_method(Transaction, "set_queue_start", set_transaction_queue_start, 1);
  rb_define_method(Transaction, "set_metadata",    set_transaction_metadata,    2);
  rb_define_method(Transaction, "finish",          finish_transaction,          1);
  rb_define_method(Transaction, "complete",        complete_transaction,        0);
  rb_define_method(Transaction, "to_json",         transaction_to_json,         0);

  // Create a data map or array
  rb_define_singleton_method(Extension, "data_map_new", data_map_new, 0);
  rb_define_singleton_method(Extension, "data_array_new", data_array_new, 0);

  // Add content to a data map
  rb_define_method(Data, "set_string",  data_set_string,  2);
  rb_define_method(Data, "set_integer", data_set_integer, 2);
  rb_define_method(Data, "set_float",   data_set_float,   2);
  rb_define_method(Data, "set_boolean", data_set_boolean, 2);
  rb_define_method(Data, "set_nil",     data_set_nil,     1);
  rb_define_method(Data, "set_data",    data_set_data,    2);

  // Add content to a data array
  rb_define_method(Data, "append_string",  data_append_string,  1);
  rb_define_method(Data, "append_integer", data_append_integer, 1);
  rb_define_method(Data, "append_float",   data_append_float,   1);
  rb_define_method(Data, "append_boolean", data_append_boolean, 1);
  rb_define_method(Data, "append_nil",     data_append_nil,     0);
  rb_define_method(Data, "append_data",    data_append_data,    1);

  // Data equality
  rb_define_method(Data, "==", data_equal, 1);

  // Get JSON content of a data
  rb_define_method(Data, "to_s", data_to_s, 0);

  // Other helper methods
  rb_define_singleton_method(Extension, "install_allocation_event_hook", install_allocation_event_hook, 0);
  rb_define_singleton_method(Extension, "running_in_container?", running_in_container, 0);
  rb_define_singleton_method(Extension, "set_environment_metadata", set_environment_metadata, 2);

  // Metrics
  rb_define_singleton_method(Extension, "set_gauge",              set_gauge,              3);
  rb_define_singleton_method(Extension, "set_host_gauge",         set_host_gauge,         2);
  rb_define_singleton_method(Extension, "set_process_gauge",      set_process_gauge,      2);
  rb_define_singleton_method(Extension, "increment_counter",      increment_counter,      3);
  rb_define_singleton_method(Extension, "add_distribution_value", add_distribution_value, 3);
}
