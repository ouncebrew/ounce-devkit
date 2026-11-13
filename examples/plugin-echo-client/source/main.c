// SPDX-License-Identifier: MIT
// Open the published plugin-echo service and record its answer on SD.
#include <stdio.h>
#include <string.h>
#include <switch.h>
#include <kaihen.h>

static void recordResult(Result rc, u32 count, u32 answer) {
    FsFileSystem sd;
    if (R_FAILED(fsOpenSdCardFileSystem(&sd))) return;

    char text[96];
    int length = snprintf(text, sizeof(text),
                          "plugin-echo: result=%08x count=%u answer=%u\n",
                          rc, count, answer);
    const char* path = "/kaihen/plugin-echo-result.txt";
    fsFsDeleteFile(&sd, path);
    if (R_SUCCEEDED(fsFsCreateFile(&sd, path, length, 0))) {
        FsFile file;
        if (R_SUCCEEDED(fsFsOpenFile(&sd, path, FsOpenMode_Write, &file))) {
            fsFileWrite(&file, 0, text, length, FsWriteOption_Flush);
            fsFileClose(&file);
        }
    }
    fsFsClose(&sd);
}

int main(void) {
    Service ro = {};
    Service hen = {};
    Service plugin = {};
    u32 count = 0;
    u32 answer = 0;

    Result rc = kaihenGetRoSession(&ro);
    if (R_SUCCEEDED(rc)) rc = kaihenOpenHomebrewSession(&ro, &hen);
    if (R_SUCCEEDED(rc)) rc = henGetPluginCount(&hen, &count);

    HenPluginName name = {};
    memcpy(name.name, "plugin-echo", sizeof("plugin-echo"));
    if (R_SUCCEEDED(rc)) rc = henOpenPlugin(&hen, &name, &plugin);
    if (R_SUCCEEDED(rc)) {
        u32 input = 41;
        rc = serviceDispatchInOut(&plugin, 0, input, answer);
        serviceClose(&plugin);
    }
    recordResult(rc, count, answer);
    if (serviceIsActive(&hen)) serviceClose(&hen);
    return rc;
}
