package com.ethioclicks.ethioPromo.bussinesLogic.services.impl;

import com.ethioclicks.ethioPromo.bussinesLogic.entity.AccountCategory;
import com.ethioclicks.ethioPromo.bussinesLogic.repos.AccountCategoryRepository;
import com.ethioclicks.ethioPromo.bussinesLogic.services.AccountCategoryService;
import org.springframework.stereotype.Service;
import com.ethioclicks.ethioPromo.bussinesLogic.repos.InfluencerAccountRepository;
import org.springframework.http.HttpStatus;
import org.springframework.web.server.ResponseStatusException;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.data.domain.Sort;

import java.util.List;

@Service
public class AccountCategoryServiceImpl implements AccountCategoryService {
    private final AccountCategoryRepository accountCategoryRepository;
    private final InfluencerAccountRepository accounts;

    public AccountCategoryServiceImpl(AccountCategoryRepository accountCategoryRepository, InfluencerAccountRepository accounts) {
        this.accountCategoryRepository = accountCategoryRepository;
        this.accounts = accounts;
    }

    @Override
    @Transactional
    public AccountCategory createAccountCategory(AccountCategory accountCategory) {
        validate(accountCategory);
        if (accountCategoryRepository.existsByCategoryNameIgnoreCase(accountCategory.getCategoryName())) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "Category name already exists.");
        }
        accountCategory.setId(null);
        return accountCategoryRepository.save(accountCategory);
    }
// we need to do here
    @Override
    public AccountCategory getAccountCategoryById(Long id) {
        return accountCategoryRepository.findById(id)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Category not found."));
    }

    @Override
    public List<AccountCategory> getAllAccountCategories() {
        return accountCategoryRepository.findAll(Sort.by("displayOrder").ascending().and(Sort.by("categoryName")));
    }

    @Override
    @Transactional
    public AccountCategory updateAccountCategory(Long id, AccountCategory accountCategory) {
        validate(accountCategory);
        if (accountCategoryRepository.existsByCategoryNameIgnoreCaseAndIdNot(accountCategory.getCategoryName(), id)) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "Category name already exists.");
        }
        AccountCategory existingAccountCategory = getAccountCategoryById(id);
        existingAccountCategory.setCategoryName(accountCategory.getCategoryName());
        existingAccountCategory.setCategoryImageUrl(accountCategory.getCategoryImageUrl());
        existingAccountCategory.setDisplayOrder(accountCategory.getDisplayOrder());
        return accountCategoryRepository.save(existingAccountCategory);
    }

    @Override
    @Transactional
    public void deleteAccountCategory(Long id) {
        AccountCategory existingAccountCategory = getAccountCategoryById(id);
        if (accounts.existsByCategoryId(id)) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "Category is used by an existing channel.");
        }
        accountCategoryRepository.delete(existingAccountCategory);
    }

    private void validate(AccountCategory category) {
        if (category == null || category.getCategoryName() == null ||
                category.getCategoryName().isBlank() || category.getCategoryName().trim().length() > 100 ||
                (category.getDisplayOrder() != null && category.getDisplayOrder() < 0)) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Provide a category name and non-negative display order.");
        }
        category.setCategoryName(category.getCategoryName().trim());
        if (category.getDisplayOrder() == null) category.setDisplayOrder(0);
    }
}
