package com.ethioclicks.ethioPromo.bussinesLogic.controllers;

import com.ethioclicks.ethioPromo.bussinesLogic.entity.AccountCategory;
import com.ethioclicks.ethioPromo.bussinesLogic.entity.ChannelPlatform;
import com.ethioclicks.ethioPromo.bussinesLogic.services.AccountCategoryService;
import com.ethioclicks.ethioPromo.bussinesLogic.services.ChannelPlatformService;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;
import java.util.List;

@RestController
public class ChannelOptionsController {
    private final ChannelPlatformService platforms;
    private final AccountCategoryService categories;

    public ChannelOptionsController(ChannelPlatformService platforms, AccountCategoryService categories) {
        this.platforms = platforms;
        this.categories = categories;
    }

    @GetMapping("/admin/account-category")
    public List<AccountCategory> categories() { return categories.getAllAccountCategories(); }

    @GetMapping({"/admin/channel-platforms", "/user/channel-platforms"})
    public List<ChannelPlatform> platforms() { return platforms.list(); }

    @PostMapping("/admin/channel-platforms")
    @ResponseStatus(HttpStatus.CREATED)
    public ChannelPlatform create(@RequestBody ChannelPlatform input) { return platforms.create(input); }

    @PutMapping("/admin/channel-platforms/{code}")
    public ChannelPlatform update(@PathVariable String code, @RequestBody ChannelPlatform input) {
        return platforms.update(code, input);
    }

    @DeleteMapping("/admin/channel-platforms/{code}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void delete(@PathVariable String code) { platforms.delete(code); }
}
