// SPDX-License-Identifier: MIT
// An opt-in kaiHEN IPC plugin. Install plugin-echo.nso in
// /kaihen/plugins; homebrew opens it under the name "plugin-echo".
#include <string.h>
#include <switch.h>
#include <kaihen/plugin.h>

u32 __nx_applet_type = AppletType_None;
size_t __nx_heap_size = 0x200000;

void __appInit(void) {}
void __appExit(void) {}

typedef struct {
    Handle exit_write;
} EchoContext;

static Result echoCommand(u32 command_id, const void* input,
                          size_t input_size, void* output,
                          size_t* output_size, void* context) {
    EchoContext* echo = (EchoContext*)context;
    if (command_id == 0 && input_size >= sizeof(u32)) {
        u32 value;
        memcpy(&value, input, sizeof(value));
        value++;
        memcpy(output, &value, sizeof(value));
        *output_size = sizeof(value);
        return 0;
    }
    if (command_id == 1) {
        return svcSignalEvent(echo->exit_write);
    }
    if (command_id == 2) {
        svcSleepThread(10000000000LL);
        return 0;
    }
    return MAKERESULT(Module_Libnx, LibnxError_BadInput);
}

int main(void) {
    Handle ready = INVALID_HANDLE;
    Handle control_session = INVALID_HANDLE;
    Result rc = pluginRuntimeInitializeWithService(&ready, &control_session);
    if (R_FAILED(rc)) return rc;

    Handle exit_write = INVALID_HANDLE;
    Handle exit_read = INVALID_HANDLE;
    EchoContext context = {};
    PluginService service = {};
    rc = svcCreateEvent(&exit_write, &exit_read);
    if (R_SUCCEEDED(rc)) {
        context.exit_write = exit_write;
        rc = pluginServiceStart(&service, control_session, echoCommand, &context);
    }
    if (R_SUCCEEDED(rc)) rc = svcSignalEvent(ready);
    if (R_SUCCEEDED(rc)) rc = svcWaitSynchronizationSingle(exit_read, UINT64_MAX);

    if (service.started) {
        Result stop_result = pluginServiceStop(&service);
        if (R_SUCCEEDED(rc)) rc = stop_result;
    }
    if (exit_read != INVALID_HANDLE) svcCloseHandle(exit_read);
    if (exit_write != INVALID_HANDLE) svcCloseHandle(exit_write);
    pluginRuntimeExit();
    return rc;
}
