package com.ethioclicks.ethioPromo;

import com.ethioclicks.ethioPromo.bussinesLogic.entity.*;
import com.ethioclicks.ethioPromo.bussinesLogic.repos.*;
import com.ethioclicks.ethioPromo.bussinesLogic.services.ChannelPlatformService;
import com.ethioclicks.ethioPromo.bussinesLogic.services.impl.*;
import com.ethioclicks.ethioPromo.security.entity.User;
import com.ethioclicks.ethioPromo.security.enums.AccountTypeEnum;
import com.ethioclicks.ethioPromo.security.repo.UserRepo;
import org.junit.jupiter.api.Test;
import org.springframework.web.server.ResponseStatusException;
import java.util.Optional;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

class ChannelOptionsTest {
    final ChannelPlatformRepository platforms = mock(ChannelPlatformRepository.class);
    final InfluencerAccountRepository accounts = mock(InfluencerAccountRepository.class);
    final AccountCategoryRepository categories = mock(AccountCategoryRepository.class);
    final UserRepo users = mock(UserRepo.class);
    final ChannelPlatformService platformService = new ChannelPlatformService(platforms, accounts);

    ChannelPlatform platform(String code) {
        ChannelPlatform p = new ChannelPlatform();
        p.setCode(code); p.setName(code);
        return p;
    }

    @Test void newPlatformsAreSavedAndReturnedWithTheChannel() {
        ChannelPlatform linkedin = platform("LINKEDIN");
        when(platforms.findById("LINKEDIN")).thenReturn(Optional.of(linkedin));
        AccountCategory category = new AccountCategory(); category.setId(1L);
        when(categories.findById(1L)).thenReturn(Optional.of(category));
        when(users.findByUserPublicId("owner")).thenReturn(Optional.of(new User()));
        when(accounts.save(any())).thenAnswer(call -> call.getArgument(0));
        InfluencerAccount input = new InfluencerAccount();
        input.setPlatformCode("LINKEDIN");
        InfluencerAccount saved = new InfluencerAccountServiceImpl(accounts, users, categories, platformService)
            .save(input, 1L, "owner");
        assertEquals("LINKEDIN", saved.getPlatform().getCode());
        assertNull(saved.getAccountType());
        assertSame(category, saved.getCategory());
    }

    @Test void oldClientsCanStillSubmitTheOriginalEnum() {
        when(platforms.findById("YOUTUBE")).thenReturn(Optional.of(platform("YOUTUBE")));
        when(categories.findById(1L)).thenReturn(Optional.of(new AccountCategory()));
        when(users.findByUserPublicId("owner")).thenReturn(Optional.of(new User()));
        when(accounts.save(any())).thenAnswer(call -> call.getArgument(0));
        InfluencerAccount input = new InfluencerAccount(); input.setAccountType(AccountTypeEnum.YOUTUBE);
        InfluencerAccount saved = new InfluencerAccountServiceImpl(accounts, users, categories, platformService)
            .save(input, 1L, "owner");
        assertEquals(AccountTypeEnum.YOUTUBE, saved.getAccountType());
        assertEquals("YOUTUBE", saved.getPlatform().getCode());
    }

    @Test void platformsReferencedOnlyByLegacyChannelsCannotBeDeleted() {
        when(platforms.findById("YOUTUBE")).thenReturn(Optional.of(platform("YOUTUBE")));
        when(accounts.existsByAccountType(AccountTypeEnum.YOUTUBE)).thenReturn(true);
        ResponseStatusException error = assertThrows(ResponseStatusException.class,
            () -> platformService.delete("YOUTUBE"));
        assertEquals(409, error.getStatusCode().value());
        verify(platforms, never()).save(any());
    }

    @Test void customPlatformsInUseCannotBeDeleted() {
        when(platforms.findById("LINKEDIN")).thenReturn(Optional.of(platform("LINKEDIN")));
        when(accounts.existsByPlatform_Code("LINKEDIN")).thenReturn(true);
        assertThrows(ResponseStatusException.class, () -> platformService.delete("LINKEDIN"));
        verify(platforms, never()).save(any());
    }

    @Test void referencedCategoriesCannotBeDeleted() {
        AccountCategory category = new AccountCategory(); category.setId(1L);
        when(categories.findById(1L)).thenReturn(Optional.of(category));
        when(accounts.existsByCategoryId(1L)).thenReturn(true);
        assertThrows(ResponseStatusException.class,
            () -> new AccountCategoryServiceImpl(categories, accounts).deleteAccountCategory(1L));
        verify(categories, never()).delete(any());
    }

    @Test void duplicateAndBlankCategoryNamesAreRejected() {
        AccountCategoryServiceImpl service = new AccountCategoryServiceImpl(categories, accounts);
        AccountCategory input = new AccountCategory(); input.setCategoryName("  Tech  ");
        when(categories.existsByCategoryNameIgnoreCase("Tech")).thenReturn(true);
        assertEquals(409, assertThrows(ResponseStatusException.class,
            () -> service.createAccountCategory(input)).getStatusCode().value());
        input.setCategoryName(" ");
        assertEquals(400, assertThrows(ResponseStatusException.class,
            () -> service.createAccountCategory(input)).getStatusCode().value());
    }

    @Test void unavailablePlatformCannotBeSubmittedByBypassingThePicker() {
        ChannelPlatform deleted = platform("LINKEDIN"); deleted.setDeleted(true);
        when(platforms.findById("LINKEDIN")).thenReturn(Optional.of(deleted));
        assertThrows(ResponseStatusException.class, () -> platformService.requireAvailable("LINKEDIN"));
    }
}
