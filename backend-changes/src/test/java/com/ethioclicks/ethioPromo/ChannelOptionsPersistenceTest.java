package com.ethioclicks.ethioPromo;

import com.ethioclicks.ethioPromo.bussinesLogic.entity.*;
import com.ethioclicks.ethioPromo.bussinesLogic.repos.*;
import com.ethioclicks.ethioPromo.bussinesLogic.services.ChannelPlatformService;
import com.ethioclicks.ethioPromo.security.entity.User;
import com.ethioclicks.ethioPromo.security.enums.AccountTypeEnum;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.orm.jpa.DataJpaTest;
import org.springframework.boot.test.autoconfigure.jdbc.AutoConfigureTestDatabase;
import org.springframework.boot.test.autoconfigure.orm.jpa.TestEntityManager;
import org.springframework.context.annotation.Import;
import org.springframework.test.context.ActiveProfiles;
import static org.junit.jupiter.api.Assertions.*;

@DataJpaTest(properties = {
    "spring.datasource.url=jdbc:h2:mem:channel_options;NON_KEYWORDS=USER;DB_CLOSE_ON_EXIT=FALSE",
    "spring.datasource.driver-class-name=org.h2.Driver",
    "spring.datasource.username=sa", "spring.datasource.password=",
    "spring.jpa.hibernate.ddl-auto=create-drop",
    "spring.sql.init.mode=never",
    "spring.jpa.properties.hibernate.dialect=org.hibernate.dialect.H2Dialect"
})
@AutoConfigureTestDatabase(replace = AutoConfigureTestDatabase.Replace.NONE)
@ActiveProfiles("test")
@Import(ChannelPlatformService.class)
class ChannelOptionsPersistenceTest {
    @Autowired TestEntityManager em;
    @Autowired InfluencerAccountRepository accounts;
    @Autowired ChannelPlatformRepository platforms;

    @Test void customPlatformPersistsAndMultipleChannelsCanShareOneCategory() {
        ChannelPlatform platform = new ChannelPlatform();
        platform.setCode("LINKEDIN"); platform.setName("LinkedIn");
        em.persist(platform);
        AccountCategory category = new AccountCategory(); category.setCategoryName("Tech");
        em.persist(category);
        User user = new User(); user.setUserName("owner"); em.persist(user);
        for (String publicId : new String[]{"one", "two"}) {
            InfluencerAccount account = new InfluencerAccount();
            account.setAccountPublicId(publicId); account.setOwner(user);
            account.setCategory(category); account.setPlatform(platform);
            em.persistAndFlush(account);
        }
        em.clear();
        InfluencerAccount restored = accounts.findByAccountPublicId("two").orElseThrow();
        assertEquals("LinkedIn", restored.getPlatform().getName());
        assertTrue(accounts.existsByCategoryId(category.getId()));
        assertTrue(accounts.existsByPlatform_Code("LINKEDIN"));
    }

    @Test void originalOrdinalColumnRemainsReadableWithoutMigration() {
        AccountCategory category = new AccountCategory(); category.setCategoryName("News");
        em.persist(category);
        User user = new User(); user.setUserName("legacy"); em.persist(user);
        InfluencerAccount account = new InfluencerAccount();
        account.setAccountPublicId("legacy"); account.setOwner(user);
        account.setCategory(category); account.setAccountType(AccountTypeEnum.YOUTUBE);
        em.persistAndFlush(account); em.clear();
        InfluencerAccount restored = accounts.findByAccountPublicId("legacy").orElseThrow();
        assertEquals(AccountTypeEnum.YOUTUBE, restored.getAccountType());
        assertNull(restored.getPlatform());
        assertTrue(accounts.existsByAccountType(AccountTypeEnum.YOUTUBE));
        assertEquals(5, platforms.findAllByDeletedFalseOrderByDisplayOrderAscNameAsc().size());
    }
}
