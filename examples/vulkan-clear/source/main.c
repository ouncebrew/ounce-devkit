// SPDX-License-Identifier: MIT
//
// Clears the screen to a color that changes each frame, with Vulkan.
// Press + to exit.
//
// The program uses the default NWindow through VK_NN_vi_surface, as on
// Switch 1. It clears each swapchain image with vkCmdClearColorImage, so it
// needs no shaders.
#include <math.h>
#include <stdio.h>
#include <stdlib.h>

#include <switch.h>

#define VK_USE_PLATFORM_VI_NN 1
#include <vulkan/vulkan.h>

#define MAX_IMAGES 8

typedef struct {
    VkInstance instance;
    VkSurfaceKHR surface;
    VkPhysicalDevice physical_device;
    uint32_t queue_family;
    VkDevice device;
    VkQueue queue;
    VkSwapchainKHR swapchain;
    uint32_t image_count;
    VkImage images[MAX_IMAGES];
    VkCommandPool command_pool;
    VkCommandBuffer command_buffer;
    VkSemaphore acquired;
    VkSemaphore rendered;
    VkFence frame_done;
} Renderer;

// Stops the program with a message if a Vulkan call fails.
static void check(VkResult result, const char *what)
{
    if (result != VK_SUCCESS) {
        printf("%s failed: %d\n", what, result);
        exit(1);
    }
}

static void create_instance(Renderer *r)
{
    const char *extensions[] = {
        VK_KHR_SURFACE_EXTENSION_NAME,
        VK_NN_VI_SURFACE_EXTENSION_NAME,
    };
    const VkApplicationInfo app = {
        .sType = VK_STRUCTURE_TYPE_APPLICATION_INFO,
        .pApplicationName = "vulkan-clear",
        .apiVersion = VK_API_VERSION_1_3,
    };
    const VkInstanceCreateInfo info = {
        .sType = VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO,
        .pApplicationInfo = &app,
        .enabledExtensionCount = 2,
        .ppEnabledExtensionNames = extensions,
    };
    check(vkCreateInstance(&info, NULL, &r->instance), "vkCreateInstance");

    const VkViSurfaceCreateInfoNN surface = {
        .sType = VK_STRUCTURE_TYPE_VI_SURFACE_CREATE_INFO_NN,
        .window = nwindowGetDefault(),
    };
    check(vkCreateViSurfaceNN(r->instance, &surface, NULL, &r->surface),
          "vkCreateViSurfaceNN");
}

static void create_device(Renderer *r)
{
    uint32_t count = 1;
    vkEnumeratePhysicalDevices(r->instance, &count, &r->physical_device);
    if (count == 0) {
        printf("No GPU\n");
        exit(1);
    }
    r->queue_family = 0;

    const float priority = 1.0f;
    const VkDeviceQueueCreateInfo queue = {
        .sType = VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO,
        .queueFamilyIndex = r->queue_family,
        .queueCount = 1,
        .pQueuePriorities = &priority,
    };
    const char *extensions[] = {VK_KHR_SWAPCHAIN_EXTENSION_NAME};
    const VkDeviceCreateInfo info = {
        .sType = VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO,
        .queueCreateInfoCount = 1,
        .pQueueCreateInfos = &queue,
        .enabledExtensionCount = 1,
        .ppEnabledExtensionNames = extensions,
    };
    check(vkCreateDevice(r->physical_device, &info, NULL, &r->device),
          "vkCreateDevice");
    vkGetDeviceQueue(r->device, r->queue_family, 0, &r->queue);
}

static void create_swapchain(Renderer *r)
{
    VkSurfaceCapabilitiesKHR caps;
    check(vkGetPhysicalDeviceSurfaceCapabilitiesKHR(r->physical_device,
                                                    r->surface, &caps),
          "vkGetPhysicalDeviceSurfaceCapabilitiesKHR");

    uint32_t format_count = 1;
    VkSurfaceFormatKHR format;
    vkGetPhysicalDeviceSurfaceFormatsKHR(r->physical_device, r->surface,
                                         &format_count, &format);

    const VkSwapchainCreateInfoKHR info = {
        .sType = VK_STRUCTURE_TYPE_SWAPCHAIN_CREATE_INFO_KHR,
        .surface = r->surface,
        .minImageCount = caps.minImageCount,
        .imageFormat = format.format,
        .imageColorSpace = format.colorSpace,
        .imageExtent = caps.currentExtent,
        .imageArrayLayers = 1,
        .imageUsage = VK_IMAGE_USAGE_TRANSFER_DST_BIT,
        .imageSharingMode = VK_SHARING_MODE_EXCLUSIVE,
        .preTransform = VK_SURFACE_TRANSFORM_IDENTITY_BIT_KHR,
        .compositeAlpha = VK_COMPOSITE_ALPHA_OPAQUE_BIT_KHR,
        .presentMode = VK_PRESENT_MODE_FIFO_KHR,
        .clipped = VK_TRUE,
    };
    check(vkCreateSwapchainKHR(r->device, &info, NULL, &r->swapchain),
          "vkCreateSwapchainKHR");

    r->image_count = MAX_IMAGES;
    check(vkGetSwapchainImagesKHR(r->device, r->swapchain, &r->image_count,
                                  r->images),
          "vkGetSwapchainImagesKHR");
    printf("Swapchain: %ux%u, %u images\n", caps.currentExtent.width,
           caps.currentExtent.height, r->image_count);
}

static void create_frame_objects(Renderer *r)
{
    const VkCommandPoolCreateInfo pool = {
        .sType = VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO,
        .flags = VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT,
        .queueFamilyIndex = r->queue_family,
    };
    check(vkCreateCommandPool(r->device, &pool, NULL, &r->command_pool),
          "vkCreateCommandPool");

    const VkCommandBufferAllocateInfo buffer = {
        .sType = VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO,
        .commandPool = r->command_pool,
        .level = VK_COMMAND_BUFFER_LEVEL_PRIMARY,
        .commandBufferCount = 1,
    };
    check(vkAllocateCommandBuffers(r->device, &buffer, &r->command_buffer),
          "vkAllocateCommandBuffers");

    const VkSemaphoreCreateInfo semaphore = {
        .sType = VK_STRUCTURE_TYPE_SEMAPHORE_CREATE_INFO,
    };
    check(vkCreateSemaphore(r->device, &semaphore, NULL, &r->acquired),
          "vkCreateSemaphore");
    check(vkCreateSemaphore(r->device, &semaphore, NULL, &r->rendered),
          "vkCreateSemaphore");

    const VkFenceCreateInfo fence = {
        .sType = VK_STRUCTURE_TYPE_FENCE_CREATE_INFO,
        .flags = VK_FENCE_CREATE_SIGNALED_BIT,
    };
    check(vkCreateFence(r->device, &fence, NULL, &r->frame_done),
          "vkCreateFence");
}

// Records a layout change of IMAGE from OLD_LAYOUT to NEW_LAYOUT.
static void transition(VkCommandBuffer cmd, VkImage image,
                       VkImageLayout old_layout, VkImageLayout new_layout,
                       VkAccessFlags src_access, VkAccessFlags dst_access)
{
    const VkImageMemoryBarrier barrier = {
        .sType = VK_STRUCTURE_TYPE_IMAGE_MEMORY_BARRIER,
        .srcAccessMask = src_access,
        .dstAccessMask = dst_access,
        .oldLayout = old_layout,
        .newLayout = new_layout,
        .srcQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED,
        .dstQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED,
        .image = image,
        .subresourceRange = {VK_IMAGE_ASPECT_COLOR_BIT, 0, 1, 0, 1},
    };
    vkCmdPipelineBarrier(cmd, VK_PIPELINE_STAGE_TRANSFER_BIT,
                         VK_PIPELINE_STAGE_TRANSFER_BIT, 0, 0, NULL, 0, NULL,
                         1, &barrier);
}

static void draw_frame(Renderer *r, uint32_t frame)
{
    check(vkWaitForFences(r->device, 1, &r->frame_done, VK_TRUE, UINT64_MAX),
          "vkWaitForFences");
    vkResetFences(r->device, 1, &r->frame_done);

    uint32_t index;
    VkResult result = vkAcquireNextImageKHR(r->device, r->swapchain,
                                            UINT64_MAX, r->acquired,
                                            VK_NULL_HANDLE, &index);
    if (result != VK_SUCCESS && result != VK_SUBOPTIMAL_KHR)
        check(result, "vkAcquireNextImageKHR");

    // A color that moves slowly around the color wheel.
    const float t = (float)frame / 60.0f;
    const VkClearColorValue color = {{
        0.5f + 0.5f * sinf(t),
        0.5f + 0.5f * sinf(t + 2.094f),
        0.5f + 0.5f * sinf(t + 4.189f),
        1.0f,
    }};
    const VkImageSubresourceRange range = {VK_IMAGE_ASPECT_COLOR_BIT, 0, 1, 0, 1};

    VkCommandBuffer cmd = r->command_buffer;
    const VkCommandBufferBeginInfo begin = {
        .sType = VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO,
        .flags = VK_COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT,
    };
    vkResetCommandBuffer(cmd, 0);
    vkBeginCommandBuffer(cmd, &begin);
    transition(cmd, r->images[index], VK_IMAGE_LAYOUT_UNDEFINED,
               VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL, 0,
               VK_ACCESS_TRANSFER_WRITE_BIT);
    vkCmdClearColorImage(cmd, r->images[index],
                         VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL, &color, 1,
                         &range);
    transition(cmd, r->images[index], VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL,
               VK_IMAGE_LAYOUT_PRESENT_SRC_KHR, VK_ACCESS_TRANSFER_WRITE_BIT,
               0);
    check(vkEndCommandBuffer(cmd), "vkEndCommandBuffer");

    const VkPipelineStageFlags wait_stage = VK_PIPELINE_STAGE_TRANSFER_BIT;
    const VkSubmitInfo submit = {
        .sType = VK_STRUCTURE_TYPE_SUBMIT_INFO,
        .waitSemaphoreCount = 1,
        .pWaitSemaphores = &r->acquired,
        .pWaitDstStageMask = &wait_stage,
        .commandBufferCount = 1,
        .pCommandBuffers = &cmd,
        .signalSemaphoreCount = 1,
        .pSignalSemaphores = &r->rendered,
    };
    check(vkQueueSubmit(r->queue, 1, &submit, r->frame_done), "vkQueueSubmit");

    const VkPresentInfoKHR present = {
        .sType = VK_STRUCTURE_TYPE_PRESENT_INFO_KHR,
        .waitSemaphoreCount = 1,
        .pWaitSemaphores = &r->rendered,
        .swapchainCount = 1,
        .pSwapchains = &r->swapchain,
        .pImageIndices = &index,
    };
    result = vkQueuePresentKHR(r->queue, &present);
    if (result != VK_SUCCESS && result != VK_SUBOPTIMAL_KHR)
        check(result, "vkQueuePresentKHR");
}

static void destroy(Renderer *r)
{
    vkDeviceWaitIdle(r->device);
    vkDestroyFence(r->device, r->frame_done, NULL);
    vkDestroySemaphore(r->device, r->rendered, NULL);
    vkDestroySemaphore(r->device, r->acquired, NULL);
    vkDestroyCommandPool(r->device, r->command_pool, NULL);
    vkDestroySwapchainKHR(r->device, r->swapchain, NULL);
    vkDestroyDevice(r->device, NULL);
    vkDestroySurfaceKHR(r->instance, r->surface, NULL);
    vkDestroyInstance(r->instance, NULL);
}

int main(int argc, char *argv[])
{
    (void)argc;
    (void)argv;

    // Write the messages to a file on the SD card.
    freopen("sdmc:/vulkan-clear.log", "w", stdout);
    setvbuf(stdout, NULL, _IOLBF, 0);

    padConfigureInput(1, HidNpadStyleSet_NpadStandard);
    PadState pad;
    padInitializeDefault(&pad);

    Renderer renderer = {0};
    create_instance(&renderer);
    create_device(&renderer);
    create_swapchain(&renderer);
    create_frame_objects(&renderer);

    for (uint32_t frame = 0; appletMainLoop(); frame++) {
        padUpdate(&pad);
        if (padGetButtonsDown(&pad) & HidNpadButton_Plus)
            break;
        draw_frame(&renderer, frame);
    }

    destroy(&renderer);
    return 0;
}
