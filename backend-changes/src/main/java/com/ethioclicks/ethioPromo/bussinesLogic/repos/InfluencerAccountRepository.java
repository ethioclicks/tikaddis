package com.ethioclicks.ethioPromo.bussinesLogic.repos;

import com.ethioclicks.ethioPromo.bussinesLogic.entity.AccountCategory;
import com.ethioclicks.ethioPromo.bussinesLogic.entity.InfluencerAccount;
import com.ethioclicks.ethioPromo.security.enums.AccountTypeEnum;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.List;
import java.util.Optional;

public interface InfluencerAccountRepository extends JpaRepository<InfluencerAccount,Long> {
    boolean existsByCategoryId(Long categoryId);
    boolean existsByPlatform_Code(String code);
    boolean existsByAccountType(AccountTypeEnum accountType);
    @org.springframework.transaction.annotation.Transactional
    @org.springframework.data.jpa.repository.Modifying
    @Query("update InfluencerAccount a set a.platform = :platform where a.platform is null and a.accountType = :legacy")
    int linkLegacyPlatform(@Param("platform") com.ethioclicks.ethioPromo.bussinesLogic.entity.ChannelPlatform platform,
                           @Param("legacy") AccountTypeEnum legacy);
    Optional<InfluencerAccount> findByAccountPublicId(String accountPublicId);

    Page<InfluencerAccount> findAllByOwnerUserPublicId(String userPublicId, Pageable pageable);
    List<InfluencerAccount> findAllByOwnerUserPublicId(String userPublicId);

    Page<InfluencerAccount> findAllByAccountType(AccountTypeEnum accountTypeEnum, Pageable pageable);
    Page<InfluencerAccount> findAllByCategoryCategoryName(String categoryName, Pageable pageable);
    Page<InfluencerAccount> findAllByCategoryCategoryNameAndAccountType(String categoryName,AccountTypeEnum accountTypeEnum, Pageable pageable);

    Page<InfluencerAccount> findAllByCategory(AccountCategory accountCategory, Pageable pageable);
    Page<InfluencerAccount> findAllByApproved(Boolean approved, Pageable pageable);

    // Soft-delete-aware query methods (exclude deleted accounts from listings)
    Page<InfluencerAccount> findAllByDeletedFalse(Pageable pageable);
    Page<InfluencerAccount> findAllByApprovedAndDeletedFalse(Boolean approved, Pageable pageable);
    Page<InfluencerAccount> findAllByCategoryAndDeletedFalse(AccountCategory category, Pageable pageable);
    Page<InfluencerAccount> findAllByAccountTypeAndDeletedFalse(AccountTypeEnum accountType, Pageable pageable);
    Page<InfluencerAccount> findAllByCategoryCategoryNameAndDeletedFalse(String categoryName, Pageable pageable);
    Page<InfluencerAccount> findAllByCategoryCategoryNameAndAccountTypeAndDeletedFalse(String categoryName, AccountTypeEnum accountType, Pageable pageable);
    Page<InfluencerAccount> findAllByOwnerUserPublicIdAndDeletedFalse(String userPublicId, Pageable pageable);
}
