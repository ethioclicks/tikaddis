package com.ethioclicks.ethioPromo.bussinesLogic.services;

import com.ethioclicks.ethioPromo.bussinesLogic.entity.ChannelPlatform;
import com.ethioclicks.ethioPromo.bussinesLogic.repos.ChannelPlatformRepository;
import com.ethioclicks.ethioPromo.bussinesLogic.repos.InfluencerAccountRepository;
import com.ethioclicks.ethioPromo.security.enums.AccountTypeEnum;
import jakarta.annotation.PostConstruct;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;
import java.util.List;
import java.util.Locale;

@Service
public class ChannelPlatformService {
    private final ChannelPlatformRepository platforms;
    private final InfluencerAccountRepository accounts;

    public ChannelPlatformService(ChannelPlatformRepository platforms,
                                  InfluencerAccountRepository accounts) {
        this.platforms = platforms;
        this.accounts = accounts;
    }

    @PostConstruct
    void seedDefaults() {
        String[] names = {"Telegram", "YouTube", "TikTok", "Facebook", "Instagram"};
        AccountTypeEnum[] types = AccountTypeEnum.values();
        for (int i = 0; i < types.length; i++) {
            if (!platforms.existsById(types[i].name())) {
                ChannelPlatform platform = new ChannelPlatform();
                platform.setCode(types[i].name());
                platform.setName(names[i]);
                platform.setDisplayOrder(i);
                platforms.save(platform);
            }
            accounts.linkLegacyPlatform(platforms.findById(types[i].name()).orElseThrow(), types[i]);
        }
    }

    public List<ChannelPlatform> list() {
        return platforms.findAllByDeletedFalseOrderByDisplayOrderAscNameAsc();
    }

    public ChannelPlatform requireAvailable(String code) {
        if (code == null) throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Choose a platform.");
        return platforms.findById(code).filter(p -> !p.isDeleted())
            .orElseThrow(() -> new ResponseStatusException(HttpStatus.BAD_REQUEST, "Platform is not available."));
    }

    @Transactional
    public ChannelPlatform create(ChannelPlatform input) {
        validate(input);
        String code = input.getCode().trim().toUpperCase(Locale.ROOT);
        if (!code.matches("[A-Z][A-Z0-9_]{0,49}")) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Use a platform code of up to 50 letters, numbers or underscores.");
        }
        if (platforms.existsById(code) || platforms.existsByNameIgnoreCaseAndDeletedFalse(input.getName().trim())) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "Platform code or name already exists.");
        }
        input.setCode(code);
        input.setName(input.getName().trim());
        input.setDeleted(false);
        return platforms.save(input);
    }

    @Transactional
    public ChannelPlatform update(String code, ChannelPlatform input) {
        validate(input);
        ChannelPlatform existing = requireAvailable(code);
        if (platforms.existsByNameIgnoreCaseAndCodeNotAndDeletedFalse(input.getName().trim(), code)) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "Platform name already exists.");
        }
        existing.setName(input.getName().trim());
        existing.setDisplayOrder(input.getDisplayOrder());
        return platforms.save(existing);
    }

    @Transactional
    public void delete(String code) {
        ChannelPlatform platform = requireAvailable(code);
        boolean used = accounts.existsByPlatform_Code(code);
        try {
            used = used || accounts.existsByAccountType(AccountTypeEnum.valueOf(code));
        } catch (IllegalArgumentException ignored) { }
        if (used) throw new ResponseStatusException(HttpStatus.CONFLICT, "Platform is used by an existing channel.");
        // Retain a tombstone so default platforms are not recreated on restart.
        platform.setDeleted(true);
        platforms.save(platform);
    }

    private void validate(ChannelPlatform input) {
        if (input == null || input.getCode() == null || input.getName() == null ||
            input.getName().isBlank() || input.getName().trim().length() > 100 ||
            input.getDisplayOrder() == null || input.getDisplayOrder() < 0) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Provide a name, code and non-negative display order.");
        }
    }
}
