package com.ethioclicks.ethioPromo.bussinesLogic.services.impl;

import com.ethioclicks.ethioPromo.bussinesLogic.entity.AccountCategory;
import com.ethioclicks.ethioPromo.bussinesLogic.entity.InfluencerAccount;
import com.ethioclicks.ethioPromo.bussinesLogic.model.FilterCriteriaDto;
import com.ethioclicks.ethioPromo.bussinesLogic.repos.AccountCategoryRepository;
import com.ethioclicks.ethioPromo.bussinesLogic.repos.InfluencerAccountRepository;
import com.ethioclicks.ethioPromo.bussinesLogic.services.InfluencerAccountService;
import com.ethioclicks.ethioPromo.bussinesLogic.services.ChannelPlatformService;
import com.ethioclicks.ethioPromo.bussinesLogic.entity.ChannelPlatform;
import com.ethioclicks.ethioPromo.security.enums.AccountTypeEnum;
import com.ethioclicks.ethioPromo.security.entity.User;
import com.ethioclicks.ethioPromo.security.exception.BadRequestException;
import com.ethioclicks.ethioPromo.security.repo.UserRepo;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;

import java.util.*;

@Service
public class InfluencerAccountServiceImpl implements InfluencerAccountService {

   private final InfluencerAccountRepository influencerAccountRepository;
   private final UserRepo userRepo;
   private final AccountCategoryRepository accountCategoryRepository;
   private final ChannelPlatformService platformService;

    public InfluencerAccountServiceImpl(InfluencerAccountRepository influencerAccountRepository, UserRepo userRepo, AccountCategoryRepository accountCategoryRepository, ChannelPlatformService platformService) {
        this.influencerAccountRepository = influencerAccountRepository;
        this.userRepo = userRepo;
        this.accountCategoryRepository = accountCategoryRepository;
        this.platformService = platformService;
    }


    @Override
    public InfluencerAccount save(InfluencerAccount influencerAccount, Long categoryId, String posterPublicId) {
        assignPlatform(influencerAccount, influencerAccount);
        AccountCategory categoryById = accountCategoryRepository.findById(categoryId).orElseThrow(()-> new BadRequestException("Category can not  be found"));
        influencerAccount.setCategory(categoryById);
        
        // Find user and add the account to their collection
        User existingUser = userRepo.findByUserPublicId(posterPublicId).orElseThrow(()-> new BadRequestException("User can not  be found"));
        influencerAccount.setAccountPublicId(UUID.randomUUID().toString());
        influencerAccount.setApproved(false);
        influencerAccount.setVerified(false);

        // Set the owner directly so USER_ID is populated on insert
        influencerAccount.setOwner(existingUser);
        return influencerAccountRepository.save(influencerAccount);
    }

    @Override
    public Page<InfluencerAccount> getAllApprovedBusinessList(boolean b, Pageable pageable) {
        return null;
    }

    @Override
    public Page<InfluencerAccount> getBusinessSearchKeyWords(String keyword, Pageable pageable) {
        return null;
    }

    @Override
    public List<String> getBusinessTagOptions(String keyword) {
        return null;
    }

    @Override
    public Page<InfluencerAccount> getBusinessesListBySubcategory(Long subCategoryId, Pageable pageable) {
        return null;
    }

    @Override
    public Page<InfluencerAccount> getAllFeaturedList(Pageable pageable) {
        return null;
    }

    @Override
    public Page<InfluencerAccount> fetchBusinessesByFeaturedType(boolean equals, Pageable pageable) {
        return null;
    }

    @Override
    public InfluencerAccount getAccountByAccountPublicId(String accountPublicId) {
         return  influencerAccountRepository.findByAccountPublicId(accountPublicId).orElseThrow(()->new BadRequestException("Account with the Public Id is not found"));


    }

    @Override
    public Page<InfluencerAccount> userAccountsList(String userPublicId, Pageable pageable) {
        if(userPublicId == null) {
            throw new BadRequestException("User Public Id required");
        }
        return influencerAccountRepository.findAllByOwnerUserPublicIdAndDeletedFalse(userPublicId, pageable);
    }

    @Override
    public Page<InfluencerAccount> getInfluencerAccountListByCategory(Long categoryId, Pageable pageable) {
        AccountCategory category = accountCategoryRepository
                .findById(categoryId).orElseThrow(()-> new BadRequestException("Couldn't find category by category ID"));
        if(category == null) {
            throw new RuntimeException("Category not found");
        }
        return influencerAccountRepository.findAllByCategoryAndDeletedFalse(category, pageable);
    }

    @Override
    public InfluencerAccount updateInfluencerAccountProfile(InfluencerAccount influencerAccount) {
        if(influencerAccount == null || influencerAccount.getAccountPublicId() == null) {
            throw new BadRequestException("Account Public Id is required");
        }

        InfluencerAccount existingAccount = influencerAccountRepository.findByAccountPublicId(influencerAccount.getAccountPublicId()).orElseThrow(()->new BadRequestException("Account with the Public Id is not found"));
        existingAccount.setTitle(influencerAccount.getTitle());
        existingAccount.setDescription(influencerAccount.getDescription());
        existingAccount.setAccountURL(influencerAccount.getAccountURL());
        assignPlatform(existingAccount, influencerAccount);
        if (influencerAccount.getCategory() != null) {
            Long categoryId = influencerAccount.getCategory().getId();
            if (categoryId == null) throw new BadRequestException("Category ID is required");
            existingAccount.setCategory(accountCategoryRepository.findById(categoryId)
                    .orElseThrow(() -> new BadRequestException("Category cannot be found")));
        }
        existingAccount.setAudienceCount(influencerAccount.getAudienceCount());
        existingAccount.setMaxViewPerPostCount(influencerAccount.getMaxViewPerPostCount());
        existingAccount.setMinViewPerPostCount(influencerAccount.getMinViewPerPostCount());
        existingAccount.setImageURL(influencerAccount.getImageURL());
        if(influencerAccount.getTopViews() != null) existingAccount.setTopViews(influencerAccount.getTopViews());
        if(influencerAccount.getRecentViewCounts() != null) existingAccount.setRecentViewCounts(influencerAccount.getRecentViewCounts());
        if(influencerAccount.getPriceOptions() != null) existingAccount.setPriceOptions(influencerAccount.getPriceOptions());
        return influencerAccountRepository.save(existingAccount);
    }

    private void assignPlatform(InfluencerAccount target, InfluencerAccount input) {
        String code = input.getPlatformCode();
        if (code == null && input.getAccountType() != null) code = input.getAccountType().name();
        ChannelPlatform platform = platformService.requireAvailable(code);
        target.setPlatform(platform);
        try {
            target.setAccountType(AccountTypeEnum.valueOf(platform.getCode()));
        } catch (IllegalArgumentException ignored) {
            target.setAccountType(null);
        }
    }

    @Override
    public void softDeleteInfluencerAccount(String accountPublicId, String userPublicId) {
        InfluencerAccount existingAccount = influencerAccountRepository.findByAccountPublicId(accountPublicId)
                .orElseThrow(() -> new BadRequestException("Account with the Public Id is not found"));
        if (!existingAccount.getOwner().getUserPublicId().equals(userPublicId)) {
            throw new BadRequestException("You are not authorized to delete this account");
        }
        existingAccount.setDeleted(true);
        influencerAccountRepository.save(existingAccount);
    }


    @Override
    public Page<InfluencerAccount> getInfluencerAccountListByCriteria(FilterCriteriaDto filterCriteriaDto, Pageable pageable) {

       if(filterCriteriaDto==null ||(filterCriteriaDto.getCategoryName()==null && filterCriteriaDto.getAccountType()==null)){
            return influencerAccountRepository.findAllByDeletedFalse(pageable);
        }
        if (filterCriteriaDto.getCategoryName() == null) {
           return influencerAccountRepository.findAllByAccountTypeAndDeletedFalse(filterCriteriaDto.getAccountType(),pageable);
        }
        if(filterCriteriaDto.getAccountType() == null){
             return influencerAccountRepository.findAllByCategoryCategoryNameAndDeletedFalse(filterCriteriaDto.getCategoryName(),pageable);
        }

        return influencerAccountRepository.findAllByCategoryCategoryNameAndAccountTypeAndDeletedFalse(filterCriteriaDto.getCategoryName(),filterCriteriaDto.getAccountType(),pageable);

    }

    @Override
    public Page<InfluencerAccount> getAllInfluencerAccounts(Boolean isApproved, Pageable pageable) {
        if (isApproved != null) {
            return influencerAccountRepository.findAllByApprovedAndDeletedFalse(isApproved, pageable);
        }
        return influencerAccountRepository.findAllByDeletedFalse(pageable);
    }
}



