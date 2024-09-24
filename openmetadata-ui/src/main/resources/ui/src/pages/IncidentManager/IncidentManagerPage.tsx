/*
 *  Copyright 2023 Collate.
 *  Licensed under the Apache License, Version 2.0 (the "License");
 *  you may not use this file except in compliance with the License.
 *  You may obtain a copy of the License at
 *  http://www.apache.org/licenses/LICENSE-2.0
 *  Unless required by applicable law or agreed to in writing, software
 *  distributed under the License is distributed on an "AS IS" BASIS,
 *  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 *  See the License for the specific language governing permissions and
 *  limitations under the License.
 */
import { Col, Row, Typography } from 'antd';
import React from 'react';
import IncidentManager from '../../components/IncidentManager/IncidentManager.component';
import PageLayoutV1 from '../../components/PageLayoutV1/PageLayoutV1';
import { PAGE_HEADERS } from '../../constants/PageHeaders.constant';

const IncidentManagerPage = () => {
  return (
    <PageLayoutV1 pageTitle="Incident Manager">
      <Row className="p-x-lg p-b-lg p-t-md" gutter={[0, 16]}>
        <Col span={24}>
          <Typography.Title
            className="m-b-md"
            data-testid="page-title"
            level={5}>
            {PAGE_HEADERS.INCIDENT_MANAGER.header}
          </Typography.Title>
          <Typography.Paragraph
            className="text-grey-muted"
            data-testid="page-sub-title">
            {PAGE_HEADERS.INCIDENT_MANAGER.subHeader}
          </Typography.Paragraph>
        </Col>

        <Col span={24}>
          <IncidentManager />
        </Col>
      </Row>
    </PageLayoutV1>
  );
};

export default IncidentManagerPage;
