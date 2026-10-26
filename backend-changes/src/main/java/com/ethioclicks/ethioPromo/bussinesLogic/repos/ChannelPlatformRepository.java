package com.ethioclicks.ethioPromo.bussinesLogic.repos;

import com.ethioclicks.ethioPromo.bussinesLogic.entity.ChannelPlatform;
import org.springframework.data.jpa.repository.JpaRepository;
import java.util.List;

public interface ChannelPlatformRepository extends JpaRepository<ChannelPlatform, String> {
    List<ChannelPlatform> findAllByDeletedFalseOrderByDisplayOrderAscNameAsc();
    boolean existsByNameIgnoreCaseAndDeletedFalse(String name);
    boolean existsByNameIgnoreCaseAndCodeNotAndDeletedFalse(String name, String code);
}
