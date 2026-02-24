import type {ReactNode} from 'react';
import clsx from 'clsx';
import Heading from '@theme/Heading';
import styles from './styles.module.css';

type FeatureItem = {
  title: string;
  description: ReactNode;
};

const FeatureList: FeatureItem[] = [
  {
    title: 'ローカル品質管理',
    description: (
      <>
        lefthook による Git Hooks 統合で、gitleaks / secretlint / commitlint を
        コミット前に自動実行。秘密情報の漏洩を未然に防ぎます。
      </>
    ),
  },
  {
    title: 'CI/CD 基盤',
    description: (
      <>
        GitHub Actions 再利用可能ワークフローで actionlint / ghalint / gitleaks を
        CI 上で自動検証。品質ゲートを一元管理できます。
      </>
    ),
  },
  {
    title: 'ドキュメント品質',
    description: (
      <>
        textlint / markdownlint / dprint によるドキュメント自動検証・フォーマット。
        ShellSpec による Bash スクリプトのテストも標準装備。
      </>
    ),
  },
];

function Feature({title, description}: FeatureItem) {
  return (
    <div className={clsx('col col--4')}>
      <div className="text--center padding-horiz--md">
        <Heading as="h3">{title}</Heading>
        <p>{description}</p>
      </div>
    </div>
  );
}

export default function HomepageFeatures(): ReactNode {
  return (
    <section className={styles.features}>
      <div className="container">
        <div className="row">
          {FeatureList.map((props, idx) => (
            <Feature key={idx} {...props} />
          ))}
        </div>
      </div>
    </section>
  );
}
