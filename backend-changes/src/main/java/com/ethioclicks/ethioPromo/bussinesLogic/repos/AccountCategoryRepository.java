package com.ethioclicks.ethioPromo.bussinesLogic.repos;

import com.ethioclicks.ethioPromo.bussinesLogic.entity.AccountCategory;
import org.springframework.data.jpa.repository.JpaRepository;

public interface AccountCategoryRepository extends JpaRepository<AccountCategory,Long> {
    boolean existsByCategoryNameIgnoreCase(String name);
    boolean existsByCategoryNameIgnoreCaseAndIdNot(String name, Long id);

}
